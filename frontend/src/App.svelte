<script lang="ts">
  import { onMount } from 'svelte';
  import { clerk, initClerk, isSignedIn, signOut } from './lib/auth';
  import Sidebar from './lib/Sidebar.svelte';
  import ExercisePage from './lib/ExercisePage.svelte';
  import { getExercises } from './api';
  import type { Chapter, Exercise } from './types';

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
      fetchError = e instanceof Error ? e.message : 'Failed to load exercises';
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
      />
    </aside>
    <main class="main-content">
      {#if loading}
        <div class="app-state"><span class="spinner"></span></div>
      {:else if fetchError}
        <div class="app-state app-state--error">{fetchError}</div>
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

  .app-state--error { color: #dc2626; }

  .spinner {
    display: inline-block;
    width: 24px;
    height: 24px;
    border: 2px solid #e5e5e5;
    border-top-color: #6d28d9;
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
    background: #f5f3ff;
  }

  @media (prefers-color-scheme: dark) {
    .sign-in-bg { background: #1a1025; }
  }

  .sign-in-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    padding: 3rem 2.5rem;
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 4px 24px rgba(0,0,0,0.08);
    text-align: center;
  }

  @media (prefers-color-scheme: dark) {
    .sign-in-card { background: #1e1535; box-shadow: 0 4px 24px rgba(0,0,0,0.4); }
  }

  .brand {
    font-size: 2rem;
    font-weight: 700;
    color: #6d28d9;
    margin: 0;
  }

  .tagline {
    margin: 0;
    color: #888;
    font-size: 0.95rem;
  }

  .sign-in-btn {
    margin-top: 0.5rem;
    padding: 0.65rem 1.75rem;
    font-size: 0.95rem;
    font-weight: 500;
    background: #24292e;
    color: #fff;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .sign-in-btn:hover { background: #1a1e22; }
</style>
