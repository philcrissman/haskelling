<script lang="ts">
  import { onMount } from 'svelte';
  import { clerk, initClerk, isSignedIn, signOut } from './lib/auth';
  import Sidebar from './lib/Sidebar.svelte';
  import ExercisePage from './lib/ExercisePage.svelte';
  import { getExercises, ApiError } from './api';
  import type { Chapter, Exercise } from './types';

  type Theme = 'light' | 'dark';

  function getInitialTheme(): Theme {
    const saved = localStorage.getItem('haskelling:theme');
    if (saved === 'light' || saved === 'dark') return saved;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  let theme: Theme = $state(getInitialTheme());

  $effect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('haskelling:theme', theme);
  });

  function toggleTheme() {
    theme = theme === 'dark' ? 'light' : 'dark';
  }

  let clerkReady = $state(false);
  let signedIn = $state(false);
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

  const userDisplayName = $derived(
    clerk.user
      ? (clerk.user.username ?? clerk.user.firstName ?? clerk.user.primaryEmailAddress?.emailAddress ?? 'User')
      : ''
  );

  const userAvatarUrl = $derived(clerk.user?.imageUrl ?? null);

  function parseHash(): string | null {
    const m = window.location.hash.match(/^#\/exercises\/(.+)$/);
    return m ? decodeURIComponent(m[1]) : null;
  }

  function navigate(id: string) {
    window.location.hash = `/exercises/${encodeURIComponent(id)}`;
    currentId = id;
  }

  async function loadExercises() {
    loading = true;
    fetchError = null;
    try {
      const res = await getExercises();
      chapters = res.chapters;
      if (!currentId) {
        const first = chapters[0]?.exercises[0];
        if (first) navigate(first.id);
      }
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        clerk.redirectToSignIn({ redirectUrl: window.location.href });
        return;
      }
      fetchError = 'Failed to load exercises. Check your connection and try again.';
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    currentId = parseHash();
    window.addEventListener('hashchange', () => {
      currentId = parseHash();
    });

    await initClerk();
    clerkReady = true;
    signedIn = isSignedIn();

    clerk.addListener((resources) => {
      const nowSignedIn = !!resources.user;
      if (nowSignedIn && !signedIn) {
        signedIn = true;
        loadExercises();
      } else if (!nowSignedIn && signedIn) {
        signedIn = false;
        chapters = [];
      }
    });

    if (signedIn) await loadExercises();
  });

  async function handleSignOut() {
    await signOut();
    signedIn = false;
    chapters = [];
  }

  function handleSignIn() {
    clerk.redirectToSignIn({ redirectUrl: window.location.href });
  }
</script>

{#if !clerkReady}
  <div class="app-state"><span class="spinner"></span></div>

{:else if !signedIn}
  <div class="sign-in-bg">
    <div class="sign-in-card">
      <h1 class="brand">haskelling</h1>
      <p class="tagline">Learn Haskell by doing</p>
      <button class="sign-in-btn" onclick={handleSignIn}>
        Sign in with GitHub
      </button>
    </div>
  </div>

{:else}
  <div class="app-layout">
    <aside class="sidebar-container">
      <Sidebar
        {chapters}
        loading={loading}
        currentId={currentId ?? ''}
        onSelect={navigate}
        avatarUrl={userAvatarUrl}
        displayName={userDisplayName}
        onSignOut={handleSignOut}
        {theme}
        onToggleTheme={toggleTheme}
      />
    </aside>
    <main class="main-content">
      {#if loading}
        <div class="app-state"><span class="spinner"></span></div>
      {:else if fetchError}
        <div class="app-state app-state--error">
          <p class="error-msg">{fetchError}</p>
          <button class="retry-btn" onclick={loadExercises}>Retry</button>
        </div>
      {:else if currentExercise}
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
    width: 260px;
    flex-shrink: 0;
    overflow-y: auto;
    border-right: 1px solid var(--border);
    background: var(--bg-subtle);
  }

  .main-content {
    flex: 1;
    overflow-y: auto;
    background: var(--bg);
  }

  .app-state {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100vh;
    color: var(--text-3);
    font-size: 0.9rem;
  }

  .app-state--error { color: var(--rust); flex-direction: column; gap: 0.75rem; }

  .error-msg { margin: 0; font-size: 0.9rem; }

  .retry-btn {
    padding: 0.4rem 1.1rem;
    font-size: 0.82rem;
    font-weight: 500;
    background: var(--rust);
    color: #fff;
    border: none;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    letter-spacing: 0.02em;
  }

  .retry-btn:hover { opacity: 0.88; }

  .spinner {
    display: inline-block;
    width: 24px;
    height: 24px;
    border: 2px solid var(--border);
    border-top-color: var(--brand);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* Sign-in screen */

  .sign-in-bg {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100vh;
    background: var(--bg-subtle);
  }

  .sign-in-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    padding: 3rem 2.5rem;
    background: var(--bg);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-card);
    border: 1px solid var(--border);
    text-align: center;
    min-width: 280px;
  }

  .brand {
    font-family: var(--font-display);
    font-size: 2rem;
    font-weight: 700;
    font-style: italic;
    color: var(--brand);
    margin: 0;
  }

  .tagline {
    margin: 0;
    color: var(--text-3);
    font-family: var(--font-mono);
    font-size: 0.68rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
  }

  .sign-in-btn {
    margin-top: 0.5rem;
    padding: 0.65rem 1.75rem;
    font-size: 0.9rem;
    font-weight: 500;
    background: #24292e;
    color: #fff;
    border: none;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .sign-in-btn:hover { background: #1a1e22; }
</style>
