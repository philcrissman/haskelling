<script lang="ts">
  import CodeEditor from './lib/CodeEditor.svelte';

  let code = $state('module HelloWorld where\n\ngreet :: String\ngreet = undefined\n');
</script>

<main>
  <h1>haskelling</h1>
  <CodeEditor value={code} onChange={(v) => { code = v; }} />
</main>

<style>
  main {
    font-family: sans-serif;
    padding: 2rem;
  }
</style>
