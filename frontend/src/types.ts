export type SubmissionStatus =
  | "pass"
  | "fail"
  | "compile_error"
  | "timeout"
  | "runtime_error"
  | "error";

export type ProgressStatus = "not_started" | "attempted" | "passed";

export interface Exercise {
  id: string;
  title: string;
  chapter: string;
  order: number;
  learningObjective: string;
  stubCode: string;
  hints: string[];
  dateAdded: string | null;
}

export interface Chapter {
  slug: string;
  title: string;
  description: string;
  lesson: string;
  exercises: Exercise[];
  dateAdded: string | null;
}

export interface SubmissionHistoryItem {
  id: number;
  status: SubmissionStatus;
  output: string;
  passedCount: number;
  failedCount: number;
  createdAt: string;
  code: string;
}

export interface SubmissionHistoryResponse {
  submissions: SubmissionHistoryItem[];
}

export interface ExercisesListResponse {
  chapters: Chapter[];
}

export interface SubmitRequest {
  exerciseId: string;
  code: string;
}

export interface SubmissionResult {
  status: SubmissionStatus;
  output: string;
  passedCount: number;
  failedCount: number;
}
