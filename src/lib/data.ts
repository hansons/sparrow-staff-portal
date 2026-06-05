import { supabase } from './supabase';
import type { Department, Priority, Profile, TaskComment, TaskStatus, TaskWithPeople } from './types';

const TASK_SELECT =
  '*, assignee:profiles!tasks_assignee_id_fkey(id,full_name), creator:profiles!tasks_created_by_fkey(id,full_name)';

export interface TaskInput {
  title: string;
  notes: string | null;
  due_date: string | null;
  department: Department;
  priority: Priority;
  assignee_id: string;
  status: TaskStatus;
}

// ── Reads (RLS filters rows to what the signed-in user may see) ──────
export async function fetchProfiles(): Promise<Profile[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('active', true)
    .order('full_name');
  if (error) throw new Error(error.message);
  return (data ?? []) as Profile[];
}

export async function fetchTasks(): Promise<TaskWithPeople[]> {
  const { data, error } = await supabase
    .from('tasks')
    .select(TASK_SELECT)
    .order('priority')
    .order('due_date');
  if (error) throw new Error(error.message);
  return (data ?? []) as unknown as TaskWithPeople[];
}

export async function fetchComments(): Promise<TaskComment[]> {
  const { data, error } = await supabase.from('task_comments').select('*').order('created_at');
  if (error) throw new Error(error.message);
  return (data ?? []) as TaskComment[];
}

// ── Writes (RLS enforces who may insert/update/delete) ───────────────
export async function createTask(input: TaskInput, createdBy: string): Promise<void> {
  const { error } = await supabase.from('tasks').insert({ ...input, created_by: createdBy });
  if (error) throw new Error(error.message);
}

export async function updateTask(id: string, patch: Partial<TaskInput>): Promise<void> {
  const { error } = await supabase.from('tasks').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

export async function setTaskStatus(id: string, status: TaskStatus): Promise<void> {
  const { error } = await supabase.from('tasks').update({ status }).eq('id', id);
  if (error) throw new Error(error.message);
}

export async function deleteTask(id: string): Promise<void> {
  const { error } = await supabase.from('tasks').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

export async function addComment(taskId: string, body: string, authorId: string): Promise<void> {
  const { error } = await supabase
    .from('task_comments')
    .insert({ task_id: taskId, author_id: authorId, body });
  if (error) throw new Error(error.message);
}
