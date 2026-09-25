export type Task = {
  id: string;
  title: string;
  completed: boolean;
  createdAt: number; // Unix timestamp ms
};

export type Filter = "all" | "active" | "completed";
