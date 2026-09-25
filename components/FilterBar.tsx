"use client";

import { Filter } from "@/types/task";

type Props = {
  current: Filter;
  onChange: (filter: Filter) => void;
};

const FILTERS: { label: string; value: Filter }[] = [
  { label: "All", value: "all" },
  { label: "Active", value: "active" },
  { label: "Completed", value: "completed" },
];

export function FilterBar({ current, onChange }: Props) {
  return (
    <div className="flex gap-1" role="group" aria-label="Filter tasks">
      {FILTERS.map(({ label, value }) => (
        <button
          key={value}
          onClick={() => onChange(value)}
          aria-pressed={current === value}
          className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
            current === value
              ? "bg-emerald-100 text-emerald-700"
              : "text-gray-500 hover:text-gray-700 hover:bg-gray-100"
          }`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
