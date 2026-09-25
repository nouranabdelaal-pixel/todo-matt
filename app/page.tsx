"use client";

import { useState } from "react";
import { useTasks } from "@/lib/useTasks";
import { TaskInput } from "@/components/TaskInput";
import { TaskList } from "@/components/TaskList";
import { Footer } from "@/components/Footer";
import { Filter } from "@/types/task";

export default function Home() {
  const { tasks, addTask, toggleTask, deleteTask, editTask, clearCompleted } =
    useTasks();
  const [filter, setFilter] = useState<Filter>("all");

  return (
    <main className="min-h-screen bg-gradient-to-br from-emerald-50 to-teal-100 flex flex-col items-center px-4 py-16">
      <div className="w-full max-w-md flex flex-col gap-4">
        <h1 className="text-4xl font-bold text-center text-gray-700 tracking-tight">
          todos
        </h1>

        <TaskInput onAdd={addTask} />

        <TaskList
          tasks={tasks}
          filter={filter}
          onToggle={toggleTask}
          onDelete={deleteTask}
          onEdit={editTask}
        />

        <Footer
          tasks={tasks}
          filter={filter}
          onFilterChange={setFilter}
          onClearCompleted={clearCompleted}
        />
      </div>
    </main>
  );
}
