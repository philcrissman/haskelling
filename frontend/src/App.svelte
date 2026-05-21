<script lang="ts">
  import { onMount } from 'svelte';
  import Sidebar from './lib/Sidebar.svelte';
  import ExercisePage from './lib/ExercisePage.svelte';
  import { getExercises } from './api';
  import type { Chapter, Exercise } from './types';

  let chapters: Chapter[] = $state([]);
  let loading = $state(true);
  let fetchError: string | null = $state(null);
  let currentId: string | null = $state(null);

  const currentExercise = $derived<Exercise | null>(
    chapters.flatMap(c => c.exercises).find(e => e.id === currentId) ?? null
  );

  const currentLesson = $derived(
    currentExercise
      ? (chapters.find(c => c.slug === currentExercise.chapter)?.lesson ?? '')
      : ''
  );

  function parseHash(): string | null {
    const m = window.location.hash.match(/^#\/exercises\/(.+)$/);
    return m ? decodeURIComponent(m[1]) : null;
  }

  function navigate(id: string) {
    window.location.hash = `/exercises/${encodeURIComponent(id)}`;
    currentId = id;
  }

  onMount(async () => {
    currentId = parseHash();
    window.addEventListener('hashchange', () => {
      currentId = parseHash();
    });

    try {
      const res = await getExercises();
      chapters = res.chapters;
      if (!currentId) {
        const first = chapters[0]?.exercises[0];
        if (first) navigate(first.id);
      }
    } catch (e) {
      fetchError = e instanceof Error ? e.message : 'Failed to load exercises';
    } finally {
      loading = false;
    }
  });
</script>

{#if loading}
  <div class="app-state">Loading…</div>
{:else if fetchError}
  <div class="app-state app-state--error">{fetchError}</div>
{:else}
  <div class="app-layout">
    <aside class="sidebar-container">
      <Sidebar {chapters} currentId={currentId ?? ''} onSelect={navigate} />
    </aside>
    <main class="main-content">
      {#if currentExercise}
        <ExercisePage exercise={currentExercise} lesson={currentLesson} />
      {:else}
        <div class="app-state">Select an exercise to get started.</div>
      {/if}
    </main>
  </div>
{/if}

<style>
  .app-layout {
    display: flex;
    height: 100vh;
    overflow: hidden;
  }

  .sidebar-container {
    width: 240px;
    flex-shrink: 0;
    overflow-y: auto;
    border-right: 1px solid #e5e5e5;
    background: #fafafa;
  }

  @media (prefers-color-scheme: dark) {
    .sidebar-container {
      border-right-color: #2a2a2a;
      background: #111;
    }
  }

  .main-content {
    flex: 1;
    overflow-y: auto;
  }

  .app-state {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100vh;
    color: #888;
    font-size: 0.95rem;
  }

  .app-state--error {
    color: #dc2626;
  }
</style>
