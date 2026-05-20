<script lang="ts">
  import CodeEditor from './CodeEditor.svelte';
  import { submitCode } from '../api';
  import type { Exercise, SubmissionResult } from '../types';

  interface Props {
    exercise: Exercise;
  }

  const { exercise }: Props = $props();

  let code = $state('');
  let submitting = $state(false);
  let result: SubmissionResult | null = $state(null);

  // Syncs stub code on mount and resets it when navigating to a new exercise.
  // $effect.pre runs before the DOM update so the editor never renders stale.
  $effect.pre(() => {
    code = exercise.stubCode;
    result = null;
  });

  async function handleSubmit() {
    if (submitting) return;
    submitting = true;
    result = null;
    try {
      result = await submitCode({ exerciseId: exercise.id, code });
    } catch (e) {
      result = {
        status: 'error',
        output: e instanceof Error ? e.message : 'An unexpected error occurred.',
        passedCount: 0,
        failedCount: 0,
      };
    } finally {
      submitting = false;
    }
  }

  const statusLabel: Record<string, string> = {
    pass:          'All tests passed',
    fail:          'Tests failed',
    compile_error: 'Compile error',
    timeout:       'Timed out',
    runtime_error: 'Runtime error',
    error:         'Error',
  };

  const humanMessage: Record<string, string> = {
    timeout:       'Execution timed out. Check for infinite loops or very slow recursion.',
    runtime_error: 'The program crashed at runtime.',
    error:         'An unexpected error occurred. Try again.',
  };
</script>

<div class="exercise-page">
  <header class="exercise-header">
    <h1>{exercise.title}</h1>
    <p class="learning-objective">{exercise.learningObjective}</p>
  </header>

  <div class="editor-area">
    <CodeEditor value={code} onChange={(v) => { code = v; }} readOnly={submitting} />
  </div>

  <div class="actions">
    <button
      class="submit-btn"
      type="button"
      disabled={submitting}
      onclick={handleSubmit}
    >
      {submitting ? 'Submitting…' : 'Submit'}
    </button>
  </div>

  {#if result}
    <div class="result result--{result.status}">
      <div class="result-header">
        <span class="result-badge">{statusLabel[result.status] ?? result.status}</span>
        {#if result.status === 'pass' || result.status === 'fail'}
          <span class="result-counts">
            {result.passedCount} passed · {result.failedCount} failed
          </span>
        {/if}
      </div>

      {#if result.status === 'pass' || result.status === 'fail'}
        {#if result.output}
          <pre class="result-output">{result.output}</pre>
        {/if}
      {:else if result.status === 'compile_error'}
        <pre class="result-output">{result.output}</pre>
      {:else}
        <p class="result-message">{humanMessage[result.status] ?? result.output}</p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .exercise-page {
    max-width: 860px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .exercise-header {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  h1 {
    font-size: 1.5rem;
    font-weight: 600;
    margin: 0;
  }

  .learning-objective {
    margin: 0;
    color: #555;
    font-size: 0.95rem;
  }

  @media (prefers-color-scheme: dark) {
    .learning-objective { color: #aaa; }
  }

  .editor-area :global(.editor) {
    min-height: 240px;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
  }

  .submit-btn {
    padding: 0.5rem 1.5rem;
    font-size: 0.95rem;
    font-weight: 500;
    border: none;
    border-radius: 4px;
    background: #6d28d9;
    color: #fff;
    cursor: pointer;
    min-width: 8rem;
  }

  .submit-btn:hover:not(:disabled) {
    background: #5b21b6;
  }

  .submit-btn:disabled {
    opacity: 0.65;
    cursor: not-allowed;
  }

  .submit-btn:focus-visible {
    outline: 2px solid #6d28d9;
    outline-offset: 2px;
  }

  /* Result panel */

  .result {
    border-radius: 6px;
    border: 1px solid transparent;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .result--pass {
    background: #f0fdf4;
    border-color: #86efac;
  }

  .result--fail,
  .result--compile_error,
  .result--runtime_error,
  .result--error {
    background: #fff1f2;
    border-color: #fda4af;
  }

  .result--timeout {
    background: #fffbeb;
    border-color: #fcd34d;
  }

  @media (prefers-color-scheme: dark) {
    .result--pass          { background: #052e16; border-color: #166534; }
    .result--fail,
    .result--compile_error,
    .result--runtime_error,
    .result--error         { background: #2d0a0f; border-color: #9f1239; }
    .result--timeout       { background: #1c1500; border-color: #92400e; }
  }

  .result-header {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .result-badge {
    font-weight: 600;
    font-size: 0.9rem;
  }

  .result-counts {
    font-size: 0.85rem;
    opacity: 0.8;
  }

  .result-output {
    margin: 0;
    font-family: ui-monospace, Consolas, monospace;
    font-size: 0.82rem;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
    max-height: 20rem;
    overflow-y: auto;
  }

  .result-message {
    margin: 0;
    font-size: 0.9rem;
  }
</style>
