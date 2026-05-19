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
}

export interface Chapter {
  slug: string;
  title: string;
  exercises: Exercise[];
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
