# blast-radius.ps1
# Lists the code affected by your uncommitted changes.
# Steps: git diff -> graph of the OLD code -> walk dependencies by node id -> tsc
#
# Walks graph.json directly instead of calling "graphify affected", so items
# with the same name in different files (like two "Props") don't get mixed up.

param(
    [int]$Depth = 2    # how many steps back to follow (same default as graphify affected)
)

$ErrorActionPreference = "Stop"

# Relations that mean "A depends on B" (same list graphify affected uses).
# "contains" is left out: it only means a file holds a function.
$dependRelations = @('calls','indirect_call','references','imports','imports_from',
                     'dynamic_import','re_exports','inherits','extends','implements',
                     'uses','mixes_in','embeds','requires')

# ------------------------------------------------------------------
# 1. What changed (code files only)
# ------------------------------------------------------------------
$changed = @(git diff --name-only HEAD | Where-Object { $_ -match '\.(ts|tsx|js|jsx|java|py)$' })
if (-not $changed) { Write-Host "No code changes found."; exit }

# ------------------------------------------------------------------
# 2. Build the graph from the LAST COMMIT (old code), then restore your changes
# ------------------------------------------------------------------
Write-Host "Building graph of the code before your change..."
git stash push --quiet
try     { graphify update . | Out-Null }
finally { git stash pop --quiet }

# ------------------------------------------------------------------
# 3. Load the graph and work out its field names
# ------------------------------------------------------------------
$graph = Get-Content graphify-out\graph.json -Raw | ConvertFrom-Json

function Pick($obj, $candidates) {
    $names = $obj.PSObject.Properties.Name
    $candidates | Where-Object { $names -contains $_ } | Select-Object -First 1
}

$nodes = $graph.nodes
$edges = if ($graph.links) { $graph.links } elseif ($graph.edges) { $graph.edges } else { $null }
if (-not $nodes -or -not $edges) {
    Write-Host "Can't find nodes/edges. Top-level fields are: $($graph.PSObject.Properties.Name)"; exit
}

$idField   = Pick $nodes[0] @('id','key')
$nameField = Pick $nodes[0] @('label','name','id')
$fileField = Pick $nodes[0] @('source_file','src','file','path')
$lineField = Pick $nodes[0] @('source_location','loc','line','location')
$srcField  = Pick $edges[0] @('source','from','src')
$tgtField  = Pick $edges[0] @('target','to','dst')
$relField  = Pick $edges[0] @('relation','type','label','kind')

if (-not ($idField -and $fileField -and $srcField -and $tgtField -and $relField)) {
    Write-Host "Couldn't recognise the graph format."
    Write-Host "  Node fields: $($nodes[0].PSObject.Properties.Name)"
    Write-Host "  Edge fields: $($edges[0].PSObject.Properties.Name)"
    exit
}

# Quick lookup: id -> node
$byId = @{}
foreach ($n in $nodes) { $byId["$($n.$idField)"] = $n }

function FileOf($n) { ("$($n.$fileField)" -replace '\\','/') }
function InChanged($path) { $path -and ($changed | Where-Object { $path.EndsWith($_) }) }

# Reverse lookup: target id -> list of (source id, relation)
$dependents = @{}
foreach ($e in $edges) {
    if ($dependRelations -notcontains "$($e.$relField)") { continue }
    $t = "$($e.$tgtField)"
    if (-not $dependents.ContainsKey($t)) { $dependents[$t] = @() }
    $dependents[$t] += [pscustomobject]@{ Id = "$($e.$srcField)"; Relation = "$($e.$relField)" }
}

# ------------------------------------------------------------------
# 4. Everything that lives in the changed files:
#    functions, types and constants (not the file node itself)
# ------------------------------------------------------------------
$changedNodes = @($nodes | Where-Object {
    (InChanged (FileOf $_)) -and ("$($_.$nameField)" -notmatch '\.(ts|tsx|js|jsx|java|py)$')
})

# ------------------------------------------------------------------
# 5. Walk backwards from each changed item, by id, up to $Depth steps
# ------------------------------------------------------------------
$results = foreach ($start in $changedNodes) {
    $startId = "$($start.$idField)"
    $seen    = @{ $startId = $true }
    $current = @($startId)

    for ($step = 1; $step -le $Depth; $step++) {
        $next = @()
        foreach ($id in $current) {
            if (-not $dependents.ContainsKey($id)) { continue }
            foreach ($d in $dependents[$id]) {
                if ($seen.ContainsKey($d.Id)) { continue }
                $seen[$d.Id] = $true
                $next += $d.Id
                $n = $byId[$d.Id]
                if ($n) {
                    [pscustomobject]@{
                        Changed  = "$($start.$nameField)"
                        Affected = "$($n.$nameField)"
                        Relation = $d.Relation
                        Steps    = $step
                        File     = FileOf $n
                        Line     = if ($lineField) { "$($n.$lineField)" } else { "" }
                    }
                }
            }
        }
        $current = $next
    }
}

# ------------------------------------------------------------------
# 6. Blast radius = affected code OUTSIDE the files you changed
# ------------------------------------------------------------------
$radius = @($results | Where-Object { -not (InChanged $_.File) } |
            Sort-Object Steps, File, Affected -Unique)

# ------------------------------------------------------------------
# 7. Report
# ------------------------------------------------------------------
Write-Host "`n=== Changed files ==="
$changed | ForEach-Object { "  $_" }

Write-Host "`n=== Changed items (functions, types, constants) ==="
$changedNodes | ForEach-Object { "  $($_.$nameField)   ($(FileOf $_))" }

Write-Host "`n=== Blast radius (where to look) ==="
if ($radius) {
    $radius | Format-Table Changed, Affected, Relation, Steps, File, Line -AutoSize | Out-String | Write-Host
    Write-Host "  Steps 1 = uses your change directly (most likely to break)"
    Write-Host "  Steps 2 = uses something that uses it (often a false alarm)"
} else {
    Write-Host "  Nothing outside the changed files depends on them."
}

Write-Host "`n=== Not covered by the graph ==="
Write-Host "  Props passed from parent to child components are not edges in the graph."
Write-Host "  Rely on the compiler check below for those."

# ------------------------------------------------------------------
# 8. What's actually broken (the compiler)
# ------------------------------------------------------------------
Write-Host "`n=== Compiler check (what is actually broken) ==="
npx tsc --noEmit
if ($LASTEXITCODE -eq 0) { Write-Host "  No type errors." }