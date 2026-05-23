<script lang="ts">
  import { marked } from 'marked';

  interface Props {
    title: string;
    lesson: string;
  }

  const { title, lesson }: Props = $props();

  const lessonHtml = $derived(marked.parse(lesson) as string);
</script>

<div class="lesson-page">
  <header class="lesson-header">
    <h1>{title}</h1>
    <p class="lesson-label">Chapter lesson</p>
  </header>
  <div class="prose">
    {@html lessonHtml}
  </div>
</div>

<style>
  .lesson-page {
    max-width: 860px;
    margin: 0 auto;
    padding: 2.25rem 1.75rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .lesson-header {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--border);
  }

  h1 {
    font-family: var(--font-display);
    font-size: 1.6rem;
    font-weight: 700;
    margin: 0;
    line-height: 1.15;
  }

  .lesson-label {
    margin: 0;
    color: var(--text-3);
    font-family: var(--font-mono);
    font-size: 0.62rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
  }

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

  @media (max-width: 640px) {
    .lesson-page {
      padding: 1.25rem 1rem;
      gap: 1.25rem;
    }
  }
</style>
