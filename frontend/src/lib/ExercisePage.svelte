<script lang="ts">
  import { marked } from 'marked';
  import CodeEditor from './CodeEditor.svelte';
  import { submitCode, getHistory, ApiError } from '../api';
  import { clerk } from './auth';
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

  let lastExerciseId = '';

  $effect.pre(() => {
    const id = exercise.id;
    if (id === lastExerciseId) return;
    lastExerciseId = id;

    const raw = localStorage.getItem(`haskelling:code:${id}`);
    const hasUserCode = raw !== null && raw !== '' && raw !== exercise.stubCode;
    code = hasUserCode ? raw : exercise.stubCode;
    result = null;
    hintsRevealed = 0;
    history = [];
    historyVisible = false;
    if (!hasUserCode) restoreFromHistory(id, exercise.stubCode);
  });

  async function restoreFromHistory(exerciseId: string, stubCode: string) {
    try {
      const resp = await getHistory(exerciseId);
      const latest = resp.submissions[0];
      if (latest?.code && exercise.id === exerciseId && code === stubCode) {
        code = latest.code;
        localStorage.setItem(`haskelling:code:${exerciseId}`, latest.code);
      }
    } catch {
      // unauthenticated or no history — fall back to stub silently
    }
  }

  async function handleSubmit() {
    if (submitting) return;
    submitting = true;
    result = null;
    try {
      result = await submitCode({ exerciseId: exercise.id, code });
      if (historyVisible) await loadHistory();
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        clerk.redirectToSignIn({ redirectUrl: window.location.href });
        return;
      }
      let message: string;
      if (e instanceof ApiError) {
        if (e.status === 429) {
          const delay = e.retryAfter ? ` Please wait ${e.retryAfter}s before trying again.` : '';
          message = `Too many submissions.${delay}`;
        } else if (e.status === 502 || e.status === 504) {
          message = 'The evaluation service is temporarily unavailable. Please try again shortly.';
        } else {
          message = 'An unexpected error occurred. Please try again.';
        }
      } else {
        message = 'Network error. Check your connection and try again.';
      }
      result = { status: 'error', output: message, passedCount: 0, failedCount: 0 };
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

  const isMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform);
  const shortcutHint = isMac ? '⌘↵' : '⌃↵';

  function onKeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      handleSubmit();
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
  };

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  }
</script>

<svelte:window onkeydown={onKeydown} />

<div class="sr-only" aria-live="polite" aria-atomic="true">
  {#if result}
    {statusLabel[result.status] ?? result.status}{result.status === 'pass' || result.status === 'fail' ? ` — ${result.passedCount} passed, ${result.failedCount} failed` : ''}
  {/if}
</div>

<div class="exercise-page">
  {#if lesson}
    <div class="tab-bar" role="tablist" aria-label="View">
      <button
        id="tab-btn-exercise"
        role="tab"
        aria-selected={activeTab === 'exercise'}
        aria-controls="tab-panel-exercise"
        class="tab-btn"
        class:active={activeTab === 'exercise'}
        onclick={() => activeTab = 'exercise'}
      >Exercise</button>
      <button
        id="tab-btn-lesson"
        role="tab"
        aria-selected={activeTab === 'lesson'}
        aria-controls="tab-panel-lesson"
        class="tab-btn"
        class:active={activeTab === 'lesson'}
        onclick={() => activeTab = 'lesson'}
      >Lesson</button>
    </div>
  {/if}

  {#if activeTab === 'lesson' && lesson}
    <div id="tab-panel-lesson" role="tabpanel" aria-labelledby="tab-btn-lesson" class="lesson-panel prose">
      {@html lessonHtml}
    </div>
  {:else}
    <div id="tab-panel-exercise" role={lesson ? 'tabpanel' : undefined} aria-labelledby={lesson ? 'tab-btn-exercise' : undefined}>
    <header class="exercise-header">
      <h1>{exercise.title}</h1>
      <p class="learning-objective">{exercise.learningObjective}</p>
    </header>

    <div class="editor-area">
      <CodeEditor value={code} onChange={(v) => { code = v; localStorage.setItem(storageKey, v); }} readOnly={submitting} />
    </div>

    <div class="actions">
      <button
        class="submit-btn"
        type="button"
        disabled={submitting}
        onclick={handleSubmit}
      >
        {submitting ? 'Submitting…' : 'Submit'}
        {#if !submitting}<kbd class="shortcut-hint">{shortcutHint}</kbd>{/if}
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
        <h2 class="hints-label">Hints</h2>
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
      <button class="history-toggle" onclick={toggleHistory} aria-expanded={historyVisible}>
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
    </div><!-- /tab-panel-exercise -->
  {/if}
</div>

<style>
  .exercise-page {
    max-width: 860px;
    margin: 0 auto;
    padding: 2.25rem 1.75rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  /* Tabs */

  .tab-bar {
    display: flex;
    border-bottom: 1px solid var(--border);
    gap: 0;
    margin-bottom: -0.5rem;
  }

  .tab-btn {
    padding: 0.5rem 1.25rem;
    font-family: var(--font-sans);
    font-size: 0.875rem;
    font-weight: 400;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
    color: var(--text-3);
    cursor: pointer;
    transition: color 0.1s;
  }

  .tab-btn:hover { color: var(--text); }
  .tab-btn.active { color: var(--brand); border-bottom-color: var(--brand-border); }

  /* Lesson panel */

  .lesson-panel { padding-top: 0.5rem; }

  .prose :global(h1),
  .prose :global(h2),
  .prose :global(h3) {
    font-family: var(--font-display);
    margin: 1.5em 0 0.5em;
  }

  .prose :global(h1) { font-size: 1.5rem; }
  .prose :global(h2) { font-size: 1.2rem; }
  .prose :global(h3) { font-size: 1rem; }
  .prose :global(p)  { margin: 0 0 1em; line-height: 1.75; }

  .prose :global(pre) {
    background: var(--bg-code);
    padding: 0.75rem 1rem;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    overflow-x: auto;
    font-size: 0.85rem;
    line-height: 1.6;
    margin: 0 0 1em;
  }

  .prose :global(code) { font-family: var(--font-mono); }

  .prose :global(:not(pre) > code) {
    background: var(--bg-code);
    padding: 0.15em 0.35em;
    border-radius: var(--radius-sm);
    font-size: 0.88em;
  }

  .prose :global(ul),
  .prose :global(ol) { padding-left: 1.5rem; margin: 0 0 1em; }

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
    border: 1px solid var(--border);
    text-align: left;
  }

  .prose :global(th) { background: var(--bg-subtle); font-weight: 500; }

  /* Exercise header */

  .exercise-header {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  h1 {
    font-family: var(--font-display);
    font-size: 1.6rem;
    font-weight: 700;
    margin: 0;
    line-height: 1.15;
  }

  .learning-objective {
    margin: 0;
    color: var(--text-2);
    font-size: 0.925rem;
    font-style: italic;
  }

  .editor-area :global(.editor) { min-height: 240px; }

  /* Submit */

  .actions { display: flex; justify-content: flex-end; }

  .submit-btn {
    padding: 0.5rem 1.5rem;
    font-size: 0.9rem;
    font-weight: 500;
    font-family: var(--font-sans);
    border: none;
    border-radius: var(--radius-md);
    background: var(--brand);
    color: #fff;
    cursor: pointer;
    min-width: 8rem;
    min-height: 44px;
    letter-spacing: 0.01em;
    transition: background 0.1s;
  }

  .submit-btn:hover:not(:disabled) { background: var(--brand-hover); }
  .submit-btn:disabled { opacity: 0.6; cursor: not-allowed; }

  .shortcut-hint {
    margin-left: 0.5rem;
    font-family: var(--font-mono);
    font-size: 0.72rem;
    opacity: 0.65;
    background: rgba(255,255,255,0.15);
    border-radius: var(--radius-sm);
    padding: 0.1em 0.35em;
  }

  /* Result panel */

  .result {
    border-radius: var(--radius-md);
    border: 1px solid transparent;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .result--pass                                    { background: var(--pass-bg); border-color: var(--pass-border); }
  .result--fail,
  .result--compile_error,
  .result--runtime_error,
  .result--error                                   { background: var(--fail-bg); border-color: var(--fail-border); }
  .result--timeout                                 { background: var(--warn-bg); border-color: var(--warn-border); }

  .result-header { display: flex; align-items: center; gap: 1rem; }
  .result-badge  { font-weight: 600; font-size: 0.875rem; }
  .result-counts { font-size: 0.82rem; opacity: 0.8; }

  .result-output {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 0.8rem;
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
    background: var(--hints-bg);
    border: 1px solid var(--hints-border);
    border-radius: var(--radius-md);
  }

  .hints-label {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--text-3);
  }

  .hints-list {
    margin: 0.25rem 0 0;
    padding-left: 1.25rem;
    font-size: 0.9rem;
    line-height: 1.65;
    color: var(--text-4);
  }

  .hint-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    align-self: flex-start;
    padding: 0.3rem 0.75rem;
    font-size: 0.82rem;
    font-family: var(--font-sans);
    background: var(--hints-btn-bg);
    border: 1px solid var(--hints-btn-border);
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--text-2);
    transition: background 0.1s;
  }

  .hint-btn:hover { background: var(--hints-btn-hover); }

  .hint-count { font-size: 0.72rem; color: var(--text-3); }

  .no-more-hints { margin: 0; font-size: 0.85rem; color: var(--text-3); }

  /* History */

  .history-section {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    padding-top: 0.5rem;
    border-top: 1px solid var(--border);
  }

  .history-toggle {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    background: none;
    border: none;
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 400;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--text-3);
    cursor: pointer;
    padding: 0;
    transition: color 0.1s;
  }

  .history-toggle:hover { color: var(--text-2); }

  .history-body { overflow-x: auto; }

  .history-loading,
  .history-empty { font-size: 0.875rem; color: var(--text-3); margin: 0; }

  .history-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
  }

  .history-table th {
    text-align: left;
    padding: 0.35rem 0.75rem;
    border-bottom: 1px solid var(--border);
    color: var(--text-3);
    font-family: var(--font-mono);
    font-size: 0.62rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.1em;
  }

  .history-table td {
    padding: 0.4rem 0.75rem;
    border-bottom: 1px solid var(--border-subtle);
    vertical-align: middle;
  }

  .history-date { color: var(--text-3); white-space: nowrap; }

  .status-badge {
    display: inline-block;
    padding: 0.15em 0.5em;
    border-radius: var(--radius-sm);
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .status-badge--pass                                           { background: var(--badge-pass-bg); color: var(--badge-pass-text); }
  .status-badge--fail,
  .status-badge--compile_error,
  .status-badge--runtime_error,
  .status-badge--error                                          { background: var(--badge-fail-bg); color: var(--badge-fail-text); }
  .status-badge--timeout                                        { background: var(--badge-warn-bg); color: var(--badge-warn-text); }

  @media (max-width: 640px) {
    .exercise-page {
      padding: 1.25rem 1rem;
      gap: 1.25rem;
    }

    .actions {
      justify-content: stretch;
    }

    .submit-btn {
      width: 100%;
      justify-content: center;
    }
  }
</style>
