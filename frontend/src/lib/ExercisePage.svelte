<script lang="ts">
  import CodeEditor from './CodeEditor.svelte';
  import type { Exercise } from '../types';

  interface Props {
    exercise: Exercise;
  }

  const { exercise }: Props = $props();

  let code = $state('');

  // Syncs stub code on mount and resets it when navigating to a new exercise.
  // $effect.pre runs before the DOM update so the editor never renders stale.
  $effect.pre(() => { code = exercise.stubCode; });
</script>

<div class="exercise-page">
  <header class="exercise-header">
    <h1>{exercise.title}</h1>
    <p class="learning-objective">{exercise.learningObjective}</p>
  </header>

  <div class="editor-area">
    <CodeEditor value={code} onChange={(v) => { code = v; }} />
  </div>

  <div class="actions">
    <button class="submit-btn" type="button">Submit</button>
  </div>
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
    .learning-objective {
      color: #aaa;
    }
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
  }

  .submit-btn:hover {
    background: #5b21b6;
  }

  .submit-btn:focus-visible {
    outline: 2px solid #6d28d9;
    outline-offset: 2px;
  }
</style>
