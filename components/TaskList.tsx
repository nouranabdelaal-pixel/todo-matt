"use client";

import { useMemo } from "react";
import { Task, Filter } from "@/types/task";
import { TaskItem } from "./TaskItem";

type Props = {
  tasks: Task[];
  filter: Filter;
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
  onEdit: (id: string, title: string) => void;
};

export function TaskList({ tasks, filter, onToggle, onDelete, onEdit }: Props) {
  const visible = useMemo(() => {
    const filtered =
      filter === "all"
        ? tasks
        : filter === "active"
        ? tasks.filter((t) => !t.completed)
        : tasks.filter((t) => t.completed);

    // Active tasks first (by createdAt asc), completed tasks sink to bottom (by createdAt asc)
    return [...filtered].sort((a, b) => {
      if (a.completed !== b.completed) return a.completed ? 1 : -1;
      return a.createdAt - b.createdAt;
    });
  }, [tasks, filter]);

  if (visible.length === 0) {
    const message =
      filter === "active"
        ? "No active tasks — you're all caught up!"
        : filter === "completed"
        ? "No completed tasks yet."
        : "No tasks yet. Add one above.";

    return (
      <div className="px-4 py-8 text-center text-gray-400 text-sm bg-white rounded-xl border border-gray-200">
        {message}
      </div>
    );
  }

  return (
    <ul className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      {visible.map((task) => (
        <TaskItem
          key={task.id}
          task={task}
          onToggle={onToggle}
          onDelete={onDelete}
          onEdit={onEdit}
        />
      ))}
    </ul>
  );
}
