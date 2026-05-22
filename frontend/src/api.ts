import type { Exercise, ExercisesListResponse, SubmissionHistoryResponse, SubmissionResult, SubmitRequest } from './types';
import { getToken } from './lib/auth';

export class ApiError extends Error {
  constructor(public readonly status: number, public readonly retryAfter?: number) {
    super(`HTTP ${status}`);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = await getToken();
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string> ?? {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
  const res = await fetch(path, { ...init, headers });
  if (!res.ok) {
    const retryAfter = res.headers.get('Retry-After');
    throw new ApiError(res.status, retryAfter ? parseInt(retryAfter, 10) : undefined);
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
