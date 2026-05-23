<script lang="ts">
  import { untrack } from 'svelte';
  import { basicSetup } from 'codemirror';
  import { EditorView, keymap } from '@codemirror/view';
  import { EditorState, Prec, Annotation } from '@codemirror/state';
  import { StreamLanguage } from '@codemirror/language';
  import { haskell } from '@codemirror/legacy-modes/mode/haskell';
  import { oneDark } from '@codemirror/theme-one-dark';

  const setProgrammatically = Annotation.define<boolean>();

  interface Props {
    value: string;
    onChange: (value: string) => void;
    tabSize?: number;
    readOnly?: boolean;
  }

  let { value, onChange, tabSize = 2, readOnly = false }: Props = $props();

  let container: HTMLDivElement | undefined = $state();
  let view: EditorView | undefined;

  // Mount the editor once. Props are read via untrack so changes to value,
  // tabSize, or readOnly after mount don't destroy and recreate the editor.
  $effect(() => {
    if (!container) return;

    const initialValue = untrack(() => value);
    const initialTabSize = untrack(() => tabSize);
    const initialReadOnly = untrack(() => readOnly);

    view = new EditorView({
      state: EditorState.create({
        doc: initialValue,
        extensions: [
          basicSetup,
          oneDark,
          StreamLanguage.define(haskell),
          EditorState.tabSize.of(initialTabSize),
          EditorState.readOnly.of(initialReadOnly),
          // Tab inserts spaces; Prec.highest so it overrides basicSetup's indentWithTab
          Prec.highest(
            keymap.of([{
              key: 'Tab',
              run: (v) => {
                v.dispatch(v.state.replaceSelection(' '.repeat(v.state.facet(EditorState.tabSize))));
                return true;
              },
            }])
          ),
          EditorView.updateListener.of((update) => {
            if (update.docChanged && !update.transactions.some(tr => tr.annotation(setProgrammatically))) {
              onChange(update.state.doc.toString());
            }
          }),
          EditorView.contentAttributes.of({ 'aria-label': 'Haskell code editor' }),
        ],
      }),
      parent: container,
    });

    return () => {
      view?.destroy();
      view = undefined;
    };
  });

  // Sync external value changes without recreating the editor.
  $effect(() => {
    const incoming = value;
    if (!view) return;
    const current = view.state.doc.toString();
    if (current !== incoming) {
      view.dispatch({
        changes: { from: 0, to: current.length, insert: incoming },
        annotations: setProgrammatically.of(true),
      });
    }
  });
</script>

<div bind:this={container} class="editor"></div>

<style>
  .editor {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .editor :global(.cm-editor) {
    height: 100%;
  }

  .editor :global(.cm-scroller) {
    font-family: 'Fira Code', 'Cascadia Code', 'Menlo', monospace;
    font-size: 14px;
    line-height: 1.6;
  }

  @media (max-width: 640px) {
    .editor :global(.cm-scroller) {
      font-size: 16px;
    }
  }
</style>
