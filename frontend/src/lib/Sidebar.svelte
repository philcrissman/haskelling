<script lang="ts">
  import type { Chapter } from '../types';

  interface Props {
    chapters: Chapter[];
    currentId: string;
    onSelect: (id: string) => void;
  }

  const { chapters, currentId, onSelect }: Props = $props();
</script>

<nav class="sidebar">
  <div class="sidebar-header">
    <span class="site-title">haskelling</span>
    <span class="site-tagline">Learn Haskell by doing</span>
  </div>

  {#each chapters as chapter}
    <section class="chapter-section">
      <h2 class="chapter-heading">{chapter.title}</h2>
      <ul class="exercise-list">
        {#each chapter.exercises as exercise}
          <li>
            <a
              href="#{`/exercises/${exercise.id}`}"
              class="exercise-link"
              class:active={exercise.id === currentId}
              onclick={(e) => { e.preventDefault(); onSelect(exercise.id); }}
            >
              {exercise.title}
            </a>
          </li>
        {/each}
      </ul>
    </section>
  {/each}
</nav>

<style>
  .sidebar {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 0 0 2rem;
  }

  .sidebar-header {
    display: flex;
    flex-direction: column;
    padding: 1.25rem 1rem 1rem;
    border-bottom: 1px solid #e5e5e5;
    margin-bottom: 0.5rem;
  }

  @media (prefers-color-scheme: dark) {
    .sidebar-header { border-bottom-color: #333; }
  }

  .site-title {
    font-size: 1.1rem;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: #6d28d9;
  }

  .site-tagline {
    font-size: 0.72rem;
    color: #888;
    margin-top: 0.1rem;
  }

  .chapter-section {
    padding: 0.5rem 0;
  }

  .chapter-heading {
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #888;
    padding: 0.25rem 1rem;
    margin: 0;
  }

  .exercise-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .exercise-link {
    display: block;
    padding: 0.35rem 1rem 0.35rem 1.25rem;
    font-size: 0.88rem;
    text-decoration: none;
    color: #333;
    border-left: 3px solid transparent;
    transition: background 0.1s, color 0.1s;
  }

  .exercise-link:hover {
    background: #f5f3ff;
    color: #4c1d95;
  }

  .exercise-link.active {
    border-left-color: #6d28d9;
    background: #f5f3ff;
    color: #4c1d95;
    font-weight: 500;
  }

  @media (prefers-color-scheme: dark) {
    .chapter-heading { color: #666; }
    .exercise-link { color: #ccc; }
    .exercise-link:hover { background: #2d1f4a; color: #c4b5fd; }
    .exercise-link.active { background: #2d1f4a; color: #c4b5fd; border-left-color: #7c3aed; }
  }
</style>
