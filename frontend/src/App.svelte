<script lang="ts">
  import ExercisePage from './lib/ExercisePage.svelte';
  import type { Exercise } from './types';

  const helloWorld: Exercise = {
    id: 'hello-world',
    title: 'Hello, World!',
    chapter: 'basics',
    order: 1,
    learningObjective: 'Define a function that returns a fixed String value.',
    stubCode: 'module HelloWorld where\n\ngreet :: String\ngreet = undefined',
    hints: [
      'A string literal in Haskell is written with double quotes.',
      'Replace undefined with the string value the function should return.',
      'Return the string "Hello, World!" exactly — note the comma and exclamation mark.',
    ],
  };
</script>

<ExercisePage exercise={helloWorld} />
