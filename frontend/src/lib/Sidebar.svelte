<script lang="ts">
  import type { Chapter } from '../types';

  interface Props {
    chapters: Chapter[];
    loading?: boolean;
    currentId: string;
    onSelect: (id: string) => void;
    avatarUrl: string | null;
    displayName: string;
    onSignOut: () => void;
    theme: 'light' | 'dark';
    onToggleTheme: () => void;
  }

  const { chapters, loading = false, currentId, onSelect, avatarUrl, displayName, onSignOut, theme, onToggleTheme }: Props = $props();
</script>

<nav class="sidebar" aria-label="Exercise navigation">
  <div class="sidebar-header">
    <span class="site-title">haskelling</span>
    <span class="site-tagline">Learn Haskell by doing</span>
  </div>

  <div class="chapter-list">
  {#if loading}
    {#each [4, 5, 3, 4] as count}
      <section class="chapter-section">
        <div class="skeleton skeleton--heading"></div>
        <ul class="exercise-list">
          {#each Array(count) as _}
            <li><div class="skeleton skeleton--item"></div></li>
          {/each}
        </ul>
      </section>
    {/each}
  {:else}
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
                aria-current={exercise.id === currentId ? 'page' : undefined}
                onclick={(e) => { e.preventDefault(); onSelect(exercise.id); }}
              >
                {exercise.title}
              </a>
            </li>
          {/each}
        </ul>
      </section>
    {/each}
  {/if}
  </div>

  <div class="user-footer">
    {#if avatarUrl}
      <img src={avatarUrl} alt={displayName} class="user-avatar" />
    {:else}
      <div class="user-avatar user-avatar--placeholder">
        {displayName.charAt(0).toUpperCase()}
      </div>
    {/if}
    <span class="user-name">{displayName}</span>
    <button
      class="theme-btn"
      onclick={onToggleTheme}
      aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
    >{theme === 'dark' ? '☀' : '☾'}</button>
    <button class="sign-out-btn" onclick={onSignOut} aria-label="Sign out">↩</button>
  </div>
</nav>

<style>
  .sidebar {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .chapter-list {
    flex: 1;
    overflow-y: auto;
    padding-bottom: 1rem;
  }

  .sidebar-header {
    display: flex;
    flex-direction: column;
    padding: 1.25rem 1rem 1rem;
    border-bottom: 1px solid var(--border);
    margin-bottom: 0.5rem;
  }

  .site-title {
    font-family: var(--font-display);
    font-size: 1.15rem;
    font-weight: 700;
    font-style: italic;
    letter-spacing: -0.01em;
    color: var(--brand);
  }

  .site-tagline {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    text-transform: uppercase;
    letter-spacing: 0.15em;
    color: var(--text-3);
    margin-top: 0.2rem;
  }

  /* Skeleton */

  .skeleton {
    background: linear-gradient(90deg, var(--skeleton-1) 25%, var(--skeleton-2) 50%, var(--skeleton-1) 75%);
    background-size: 200% 100%;
    animation: shimmer 1.4s infinite;
    border-radius: 2px;
  }

  .skeleton--heading {
    height: 0.55rem;
    width: 50%;
    margin: 0.65rem 1rem 0.4rem;
  }

  .skeleton--item {
    height: 0.65rem;
    width: 72%;
    margin: 0.45rem 1.25rem;
  }

  @keyframes shimmer {
    from { background-position: 200% 0; }
    to   { background-position: -200% 0; }
  }

  .chapter-section {
    padding: 0.5rem 0;
  }

  .chapter-heading {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.15em;
    color: var(--text-3);
    padding: 0.3rem 1rem;
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
    font-size: 0.875rem;
    font-weight: 300;
    text-decoration: none;
    color: var(--text);
    border-left: 3px solid transparent;
    transition: background 0.1s, color 0.1s;
  }

  .exercise-link:hover {
    background: var(--brand-subtle);
    color: var(--brand-text);
  }

  .exercise-link.active {
    border-left-color: var(--brand-border);
    background: var(--brand-subtle);
    color: var(--brand-text);
    font-weight: 400;
  }

  .user-footer {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    border-top: 1px solid var(--border);
  }

  .user-avatar {
    width: 26px;
    height: 26px;
    border-radius: 50%;
    flex-shrink: 0;
    object-fit: cover;
  }

  .user-avatar--placeholder {
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--brand);
    color: #fff;
    font-size: 0.72rem;
    font-weight: 500;
  }

  .user-name {
    flex: 1;
    font-size: 0.8rem;
    font-weight: 300;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--text-2);
  }

  .theme-btn,
  .sign-out-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-3);
    font-size: 1rem;
    padding: 0.1rem 0.25rem;
    line-height: 1;
    flex-shrink: 0;
    transition: color 0.1s;
    font-style: normal;
  }

  .theme-btn:hover,
  .sign-out-btn:hover { color: var(--text-2); }
</style>
