# blast-radius.ps1
# Lists the code affected by your uncommitted changes.
# Steps: git diff (changed LINES) -> graph of the OLD code -> walk dependencies by id -> tsc
#
# By default, only the items on the changed lines are checked.
# Use -AllItems to check every item in each changed file (the old, safer behaviour).

param(
    [int]$Depth = 2,      # how many steps back to follow
    [switch]$AllItems     # check every item in changed files, not just changed lines
)

$ErrorActionPreference = "Stop"

$dependRelations = @('calls','indirect_call','references','imports','imports_from',
                     'dynamic_import','re_exports','inherits','extends','implements',
                     'uses','mixes_in','embeds','requires')

# ------------------------------------------------------------------
# 1. What changed: files AND old line numbers
# ------------------------------------------------------------------
$codeExt = '\.(ts|tsx|js|jsx|java|py)$'
$changed = @(git diff --name-only HEAD | Where-Object { $_ -match $codeExt })
if (-not $changed) { Write-Host "No code changes found."; exit }

# file -> list of changed OLD line numbers
$changedLines = @{}
$currentFile  = $null
foreach ($line in (git diff -U0 HEAD)) {
    if ($line -match '^--- a/(.+)$') { $currentFile = $Matches[1]; continue }
    if ($line -match '^--- /dev/null') { $currentFile = $null; continue }   # brand-new file
    if ($currentFile -and $line -match '^@@ -(\d+)(?:,(\d+))? ') {
        $start = [int]$Matches[1]
        $count = if ($Matches[2] -ne $null -and $Matches[2] -ne '') { [int]$Matches[2] } else { 1 }
        if (-not $changedLines.ContainsKey($currentFile)) { $changedLines[$currentFile] = @() }
        if ($count -eq 0) {
            # Pure addition: attribute it to the line just before the insertion point
        if ($count -eq 0) {
            # Pure addition: attribute it to the line just before the insertion point
            $changedLines[$currentFile] += $(if ($start -lt 1) { 1 } else { $start })
        } else {
            $changedLines[$currentFile] += $start..($start + $count - 1)
        }        } else {
            $changedLines[$currentFile] += $start..($start + $count - 1)
        }
    }
}

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

if (-not ($idField -and $fileField -and $lineField -and $srcField -and $tgtField -and $relField)) {
    Write-Host "Couldn't recognise the graph format."
    Write-Host "  Node fields: $($nodes[0].PSObject.Properties.Name)"
    Write-Host "  Edge fields: $($edges[0].PSObject.Properties.Name)"
    exit
}

$byId = @{}
foreach ($n in $nodes) { $byId["$($n.$idField)"] = $n }

function FileOf($n)    { ("$($n.$fileField)" -replace '\\','/') }
function LineOf($n)    { if ("$($n.$lineField)" -match '(\d+)') { [int]$Matches[1] } else { 0 } }
function MatchFile($p) { $changed | Where-Object { $p -and $p.EndsWith($_) } | Select-Object -First 1 }
function IsFileNode($n){ "$($n.$nameField)" -match $codeExt }

$dependents = @{}
foreach ($e in $edges) {
    if ($dependRelations -notcontains "$($e.$relField)") { continue }
    $t = "$($e.$tgtField)"
    if (-not $dependents.ContainsKey($t)) { $dependents[$t] = @() }
    $dependents[$t] += [pscustomobject]@{ Id = "$($e.$srcField)"; Relation = "$($e.$relField)" }
}

# ------------------------------------------------------------------
# 4. Find the items that were actually edited
# ------------------------------------------------------------------
$changedNodes = @()
$fileLevel    = @()   # changes above the first item, e.g. imports

foreach ($file in $changed) {
    $items = @($nodes | Where-Object { (MatchFile (FileOf $_)) -eq $file -and -not (IsFileNode $_) } |
               Sort-Object { LineOf $_ })

    if ($AllItems -or -not $changedLines.ContainsKey($file)) {
        $changedNodes += $items
        continue
    }

    foreach ($ln in ($changedLines[$file] | Sort-Object -Unique)) {
        # closest item that starts at or before this line
        $owner = $items | Where-Object { (LineOf $_) -le $ln } | Select-Object -Last 1
        if ($owner) { $changedNodes += $owner }
        else        { $fileLevel += "$file (line $ln)" }
    }
}
$changedNodes = @($changedNodes | Sort-Object { "$($_.$idField)" } -Unique)

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
$radius = @($results | Where-Object { -not (MatchFile $_.File) } |
            Sort-Object Steps, File, Affected -Unique)

# ------------------------------------------------------------------
# 7. Report
# ------------------------------------------------------------------
Write-Host "`n=== Changed files and lines (old code) ==="
foreach ($f in $changed) {
    $ls = if ($changedLines.ContainsKey($f)) { ($changedLines[$f] | Sort-Object -Unique) -join ', ' } else { '?' }
    Write-Host "  $f   lines: $ls"
}

$mode = if ($AllItems) { "all items in changed files" } else { "items on the changed lines" }
Write-Host "`n=== Changed items ($mode) ==="
if ($changedNodes) {
    $changedNodes | ForEach-Object { "  $($_.$nameField)   ($(FileOf $_), starts L$(LineOf $_))" }
} else { Write-Host "  None matched." }

if ($fileLevel) {
    Write-Host "`n=== File-level changes (e.g. imports, not inside any item) ==="
    $fileLevel | ForEach-Object { "  $_" }
}

Write-Host "`n=== Blast radius (where to look) ==="
if ($radius) {
    $radius | Format-Table Changed, Affected, Relation, Steps, File -AutoSize | Out-String | Write-Host
    Write-Host "  Steps 1 = uses your change directly (most likely to break)"
    Write-Host "  Steps 2 = uses something that uses it (often a false alarm)"
} else {
    Write-Host "  Nothing outside the changed files depends on the changed items."
}

Write-Host "`n=== Not covered by the graph ==="
Write-Host "  - Props passed from parent to child components are not edges in the graph."
Write-Host "  - Item end lines are unknown, so a line is given to the closest item above it."
Write-Host "  Rely on the compiler check below, or rerun with -AllItems for a wider check."

# ------------------------------------------------------------------
# 8. What's actually broken (the compiler)
# ------------------------------------------------------------------
Write-Host "`n=== Compiler check (what is actually broken) ==="
npx tsc --noEmit
if ($LASTEXITCODE -eq 0) { Write-Host "  No type errors." }