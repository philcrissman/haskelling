import type { Exercise, ExercisesListResponse, SubmissionHistoryResponse, SubmissionResult, SubmitRequest } from './types';
import { getToken } from './lib/auth';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = await getToken();
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string> ?? {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
  const res = await fetch(path, { ...init, headers });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export function getExercises(): Promise<ExercisesListResponse> {
  return request<ExercisesListResponse>('/api/exercises');
}

export function getExercise(id: string): Promise<Exercise> {
  return request<Exercise>(`/api/exercises/${id}`);
}

export function submitCode(req: SubmitRequest): Promise<SubmissionResult> {
  return request<SubmissionResult>('/api/submissions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(req),
  });
}

export function getHistory(exerciseId: string): Promise<SubmissionHistoryResponse> {
  return request<SubmissionHistoryResponse>(`/api/exercises/${exerciseId}/submissions`);
}
