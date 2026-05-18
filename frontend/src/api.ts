import type { Exercise, ExercisesListResponse, SubmissionResult, SubmitRequest } from './types';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, init);
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
