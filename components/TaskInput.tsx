"use client";

import { KeyboardEvent, useRef } from "react";

type Props = {
  onAdd: (title: string) => void;
};

export function TaskInput({ onAdd }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      const value = inputRef.current?.value ?? "";
      if (value.trim()) {
        onAdd(value);
        inputRef.current!.value = "";
      }
    }
  }

  return (
    <div className="flex items-center gap-3 px-4 py-3 bg-white rounded-xl shadow-sm border border-gray-200">
      <span className="text-gray-300 text-xl select-none">○</span>
      <input
        ref={inputRef}
        type="text"
        placeholder="What needs to be done?"
        onKeyDown={handleKeyDown}
        className="flex-1 text-gray-700 placeholder-gray-400 bg-transparent outline-none text-base"
        aria-label="New task"
      />
    </div>
  );
}
