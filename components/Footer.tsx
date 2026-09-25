"use client";

import { Task, Filter } from "@/types/task";
import { FilterBar } from "./FilterBar";

type Props = {
  tasks: Task[];
  filter: Filter;
  onFilterChange: (filter: Filter) => void;
  onClearCompleted: () => void;
};

export function Footer({ tasks, filter, onFilterChange, onClearCompleted }: Props) {
  const activeCount = tasks.filter((t) => !t.completed).length;
  const completedCount = tasks.filter((t) => t.completed).length;

  if (tasks.length === 0) return null;

  return (
    <div className="flex items-center justify-between px-4 py-2 text-sm text-gray-500">
      <span>
        {activeCount} {activeCount === 1 ? "item" : "items"} left
      </span>

      <FilterBar current={filter} onChange={onFilterChange} />

      <button
        onClick={onClearCompleted}
        disabled={completedCount === 0}
        className="hover:text-gray-700 disabled:opacity-30 disabled:cursor-not-allowed transition-opacity"
      >
        Clear completed
      </button>
    </div>
  );
}
