<script lang="ts">
  import { marked } from 'marked';
  import CodeEditor from './CodeEditor.svelte';
  import { submitCode, getHistory } from '../api';
  import type { Exercise, SubmissionHistoryItem, SubmissionResult } from '../types';

  interface Props {
    exercise: Exercise;
    lesson: string;
  }

  const { exercise, lesson }: Props = $props();

  type Tab = 'exercise' | 'lesson';
  let activeTab: Tab = $state('exercise');
  let code = $state('');
  let submitting = $state(false);
  let result: SubmissionResult | null = $state(null);
  let hintsRevealed = $state(0);
  let history: SubmissionHistoryItem[] = $state([]);
  let historyLoading = $state(false);
  let historyVisible = $state(false);

  const storageKey = $derived(`haskelling:code:${exercise.id}`);

  $effect.pre(() => {
    const saved = localStorage.getItem(`haskelling:code:${exercise.id}`);
    code = saved ?? exercise.stubCode;
    result = null;
    hintsRevealed = 0;
    history = [];
    historyVisible = false;
  });

  $effect(() => {
    localStorage.setItem(storageKey, code);
  });

  async function handleSubmit() {
    if (submitting) return;
    submitting = true;
    result = null;
    try {
      result = await submitCode({ exerciseId: exercise.id, code });
      if (historyVisible) await loadHistory();
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

  async function loadHistory() {
    historyLoading = true;
    try {
      const resp = await getHistory(exercise.id);
      history = resp.submissions;
    } catch {
      // silently ignore — history is non-critical
    } finally {
      historyLoading = false;
    }
  }

  async function toggleHistory() {
    historyVisible = !historyVisible;
    if (historyVisible && history.length === 0) {
      await loadHistory();
    }
  }

  const lessonHtml = $derived(lesson ? (marked.parse(lesson) as string) : '');

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

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  }
</script>

<div class="exercise-page">
  {#if lesson}
    <div class="tab-bar" role="tablist">
      <button
        role="tab"
        aria-selected={activeTab === 'exercise'}
        class="tab-btn"
        class:active={activeTab === 'exercise'}
        onclick={() => activeTab = 'exercise'}
      >Exercise</button>
      <button
        role="tab"
        aria-selected={activeTab === 'lesson'}
        class="tab-btn"
        class:active={activeTab === 'lesson'}
        onclick={() => activeTab = 'lesson'}
      >Lesson</button>
    </div>
  {/if}

  {#if activeTab === 'lesson' && lesson}
    <div class="lesson-panel prose">
      {@html lessonHtml}
    </div>
  {:else}
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

    {#if exercise.hints.length > 0}
      <div class="hints-section">
        <div class="hints-label">Hints</div>
        {#if hintsRevealed > 0}
          <ol class="hints-list">
            {#each exercise.hints.slice(0, hintsRevealed) as hint}
              <li>{hint}</li>
            {/each}
          </ol>
        {/if}
        {#if hintsRevealed < exercise.hints.length}
          <button class="hint-btn" onclick={() => hintsRevealed++}>
            {hintsRevealed === 0 ? 'Show a hint' : 'Show next hint'}
            <span class="hint-count">{hintsRevealed}/{exercise.hints.length}</span>
          </button>
        {:else}
          <p class="no-more-hints">No more hints.</p>
        {/if}
      </div>
    {/if}

    <div class="history-section">
      <button class="history-toggle" onclick={toggleHistory}>
        {historyVisible ? '▾' : '▸'}
        Submission history
      </button>
      {#if historyVisible}
        <div class="history-body">
          {#if historyLoading}
            <p class="history-loading">Loading…</p>
          {:else if history.length === 0}
            <p class="history-empty">No submissions yet.</p>
          {:else}
            <table class="history-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Status</th>
                  <th>Passed</th>
                  <th>Failed</th>
                </tr>
              </thead>
              <tbody>
                {#each history as item}
                  <tr>
                    <td class="history-date">{formatDate(item.createdAt)}</td>
                    <td>
                      <span class="status-badge status-badge--{item.status}">
                        {statusLabel[item.status] ?? item.status}
                      </span>
                    </td>
                    <td>{item.passedCount}</td>
                    <td>{item.failedCount}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
        </div>
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

  /* Tabs */

  .tab-bar {
    display: flex;
    border-bottom: 2px solid #e5e5e5;
    gap: 0;
    margin-bottom: -0.5rem;
  }

  @media (prefers-color-scheme: dark) {
    .tab-bar { border-bottom-color: #333; }
  }

  .tab-btn {
    padding: 0.5rem 1.25rem;
    font-size: 0.9rem;
    font-weight: 500;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    color: #666;
    cursor: pointer;
  }

  .tab-btn:hover { color: #333; }
  .tab-btn.active { color: #6d28d9; border-bottom-color: #6d28d9; }

  @media (prefers-color-scheme: dark) {
    .tab-btn { color: #999; }
    .tab-btn:hover { color: #ddd; }
    .tab-btn.active { color: #a78bfa; border-bottom-color: #a78bfa; }
  }

  /* Lesson panel */

  .lesson-panel {
    padding-top: 0.5rem;
  }

  .prose :global(h1),
  .prose :global(h2),
  .prose :global(h3) {
    margin: 1.5em 0 0.5em;
    font-weight: 600;
  }

  .prose :global(h1) { font-size: 1.5rem; }
  .prose :global(h2) { font-size: 1.2rem; }
  .prose :global(h3) { font-size: 1rem; }

  .prose :global(p) { margin: 0 0 1em; line-height: 1.7; }

  .prose :global(pre) {
    background: #f4f4f5;
    padding: 0.75rem 1rem;
    border-radius: 6px;
    overflow-x: auto;
    font-size: 0.85rem;
    line-height: 1.6;
    margin: 0 0 1em;
  }

  .prose :global(code) {
    font-family: 'Fira Code', 'Cascadia Code', Menlo, monospace;
  }

  .prose :global(:not(pre) > code) {
    background: #f4f4f5;
    padding: 0.15em 0.35em;
    border-radius: 3px;
    font-size: 0.88em;
  }

  .prose :global(ul),
  .prose :global(ol) {
    padding-left: 1.5rem;
    margin: 0 0 1em;
  }

  .prose :global(li) { margin: 0.25em 0; }

  .prose :global(table) {
    width: 100%;
    border-collapse: collapse;
    margin: 0 0 1em;
    font-size: 0.9rem;
  }

  .prose :global(th),
  .prose :global(td) {
    padding: 0.4rem 0.75rem;
    border: 1px solid #e5e5e5;
    text-align: left;
  }

  .prose :global(th) { background: #f9f9f9; font-weight: 600; }

  @media (prefers-color-scheme: dark) {
    .prose :global(pre) { background: #1e1e1e; }
    .prose :global(:not(pre) > code) { background: #2a2a2a; }
    .prose :global(th) { background: #222; }
    .prose :global(th),
    .prose :global(td) { border-color: #333; }
  }

  /* Exercise header */

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

  .editor-area :global(.editor) { min-height: 240px; }

  /* Submit */

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

  .submit-btn:hover:not(:disabled) { background: #5b21b6; }
  .submit-btn:disabled { opacity: 0.65; cursor: not-allowed; }
  .submit-btn:focus-visible { outline: 2px solid #6d28d9; outline-offset: 2px; }

  /* Result panel */

  .result {
    border-radius: 6px;
    border: 1px solid transparent;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .result--pass { background: #f0fdf4; border-color: #86efac; }
  .result--fail,
  .result--compile_error,
  .result--runtime_error,
  .result--error { background: #fff1f2; border-color: #fda4af; }
  .result--timeout { background: #fffbeb; border-color: #fcd34d; }

  @media (prefers-color-scheme: dark) {
    .result--pass          { background: #052e16; border-color: #166534; }
    .result--fail,
    .result--compile_error,
    .result--runtime_error,
    .result--error         { background: #2d0a0f; border-color: #9f1239; }
    .result--timeout       { background: #1c1500; border-color: #92400e; }
  }

  .result-header { display: flex; align-items: center; gap: 1rem; }
  .result-badge { font-weight: 600; font-size: 0.9rem; }
  .result-counts { font-size: 0.85rem; opacity: 0.8; }

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

  .result-message { margin: 0; font-size: 0.9rem; }

  /* Hints */

  .hints-section {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem 1.25rem;
    background: #fafaf5;
    border: 1px solid #e8e5d0;
    border-radius: 6px;
  }

  @media (prefers-color-scheme: dark) {
    .hints-section { background: #1a1a10; border-color: #3a3820; }
  }

  .hints-label {
    font-size: 0.78rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #888;
  }

  .hints-list {
    margin: 0.25rem 0 0;
    padding-left: 1.25rem;
    font-size: 0.9rem;
    line-height: 1.6;
    color: #444;
  }

  @media (prefers-color-scheme: dark) {
    .hints-list { color: #bbb; }
  }

  .hint-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    align-self: flex-start;
    padding: 0.35rem 0.75rem;
    font-size: 0.85rem;
    background: #fff;
    border: 1px solid #d4d0b8;
    border-radius: 4px;
    cursor: pointer;
    color: #555;
  }

  .hint-btn:hover { background: #f5f3e7; }

  @media (prefers-color-scheme: dark) {
    .hint-btn { background: #222; border-color: #3a3820; color: #aaa; }
    .hint-btn:hover { background: #2a2a18; }
  }

  .hint-count {
    font-size: 0.75rem;
    opacity: 0.6;
  }

  .no-more-hints {
    margin: 0;
    font-size: 0.85rem;
    color: #888;
  }

  /* History */

  .history-section {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e5e5;
  }

  @media (prefers-color-scheme: dark) {
    .history-section { border-top-color: #333; }
  }

  .history-toggle {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    background: none;
    border: none;
    font-size: 0.88rem;
    font-weight: 500;
    color: #555;
    cursor: pointer;
    padding: 0;
  }

  .history-toggle:hover { color: #333; }

  @media (prefers-color-scheme: dark) {
    .history-toggle { color: #999; }
    .history-toggle:hover { color: #ddd; }
  }

  .history-body { overflow-x: auto; }

  .history-loading,
  .history-empty {
    font-size: 0.875rem;
    color: #888;
    margin: 0;
  }

  .history-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .history-table th {
    text-align: left;
    padding: 0.4rem 0.75rem;
    border-bottom: 1px solid #e5e5e5;
    color: #888;
    font-weight: 500;
    font-size: 0.78rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .history-table td {
    padding: 0.4rem 0.75rem;
    border-bottom: 1px solid #f0f0f0;
    vertical-align: middle;
  }

  @media (prefers-color-scheme: dark) {
    .history-table th { border-bottom-color: #333; color: #666; }
    .history-table td { border-bottom-color: #222; }
  }

  .history-date { color: #666; white-space: nowrap; }

  @media (prefers-color-scheme: dark) {
    .history-date { color: #999; }
  }

  .status-badge {
    display: inline-block;
    padding: 0.15em 0.5em;
    border-radius: 3px;
    font-size: 0.78rem;
    font-weight: 500;
  }

  .status-badge--pass { background: #dcfce7; color: #166534; }
  .status-badge--fail { background: #fee2e2; color: #991b1b; }
  .status-badge--compile_error { background: #fee2e2; color: #991b1b; }
  .status-badge--timeout { background: #fef3c7; color: #92400e; }
  .status-badge--runtime_error { background: #fee2e2; color: #991b1b; }
  .status-badge--error { background: #fee2e2; color: #991b1b; }

  @media (prefers-color-scheme: dark) {
    .status-badge--pass { background: #052e16; color: #86efac; }
    .status-badge--fail,
    .status-badge--compile_error,
    .status-badge--runtime_error,
    .status-badge--error { background: #2d0a0f; color: #fda4af; }
    .status-badge--timeout { background: #1c1500; color: #fcd34d; }
  }
</style>
