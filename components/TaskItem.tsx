"use client";

import { KeyboardEvent, MouseEvent, useEffect, useRef, useState } from "react";
import { Task } from "@/types/task";

type Props = {
  task: Task;
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
  onEdit: (id: string, title: string) => void;
};

export function TaskItem({ task, onToggle, onDelete, onEdit }: Props) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(task.title);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (editing) {
      inputRef.current?.focus();
      inputRef.current?.select();
    }
  }, [editing]);

  function commitEdit() {
    onEdit(task.id, draft);
    setEditing(false);
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") commitEdit();
    if (e.key === "Escape") {
      setDraft(task.title);
      setEditing(false);
    }
  }

  return (
    <li className="flex items-center gap-3 px-4 py-3 bg-white border-b border-gray-100 last:border-b-0 group">
      {/* Checkbox — stop propagation on double-click so two rapid clicks
          don't toggle twice before the browser fires the dblclick event */}
      <button
        onClick={() => onToggle(task.id)}
        onDoubleClick={(e: MouseEvent) => e.stopPropagation()}
        aria-label={task.completed ? "Mark incomplete" : "Mark complete"}
        className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 transition-colors ${
          task.completed
            ? "border-emerald-400 bg-emerald-400"
            : "border-gray-300 hover:border-emerald-300"
        }`}
      >
        {task.completed && (
          <svg
            className="w-3 h-3 text-white"
            viewBox="0 0 12 12"
            fill="none"
            stroke="currentColor"
            strokeWidth={2.5}
          >
            <polyline points="2,6 5,9 10,3" />
          </svg>
        )}
      </button>

      {/* Title / edit input — double-click opens edit; stopPropagation
          ensures the event never reaches the toggle button */}
      {editing ? (
        <input
          ref={inputRef}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={commitEdit}
          onKeyDown={handleKeyDown}
          className="flex-1 text-base text-gray-700 outline-none border-b border-emerald-400 bg-transparent"
          aria-label="Edit task"
        />
      ) : (
        <span
          onDoubleClick={(e: MouseEvent) => {
            e.stopPropagation();
            setDraft(task.title);
            setEditing(true);
          }}
          className={`flex-1 text-base cursor-default select-none ${
            task.completed ? "line-through text-gray-400" : "text-gray-700"
          }`}
        >
          {task.title}
        </span>
      )}

      {/* Delete button */}
      <button
        onClick={() => onDelete(task.id)}
        aria-label="Delete task"
        className="opacity-0 group-hover:opacity-100 text-gray-400 hover:text-red-400 transition-all text-lg leading-none"
      >
        ×
      </button>
    </li>
  );
}
