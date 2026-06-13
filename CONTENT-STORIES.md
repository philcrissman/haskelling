# Content Stories — Remaining LYAH Chapters

Curriculum is being rebuilt 1:1 on *Learn You a Haskell for Great Good!* (open-source edition, learnyouahaskell.github.io). Each exercise is solvable from its LYAH chapter alone; each lesson links to that chapter. See the per-exercise format in any existing chapter under `curriculum/exercises/` and the build/verify flow in `test-exercise` / `test-all-exercises`.

**Done:** ch. 2 Starting Out, ch. 3 Types and Typeclasses, ch. 4 Syntax in Functions, ch. 5 Recursion, ch. 6 Higher Order Functions, ch. 8 Making Our Own Types and Typeclasses — 7 exercises each, 42 total, live.

**Tracking:** epic issue for the remaining chapters below. These are **post-soft-launch** — we can launch on the six chapters we have and add the rest after.

---

### CONTENT-03: ch. 7 — Modules

**Size:** M · **Blocked on:** BE-31 (#90) + FE-37 (#91) multi-file support

Two flavors:
1. **Using** standard library modules — exercises that `import Data.List` (`sort`, `nub`, `group`, `sortBy`), `Data.Char` (`toUpper`, `isDigit`), `words`/`unwords`. These fit the **current single-file harness today** and could ship before multi-file.
2. **Writing your own module** — the part that actually needs multi-file editing (BE-31/FE-37): a `Geometry`-style module the learner authors in one file and imports from another.

Suggested split: do the "using modules" exercises now if we want ch. 7 sooner; defer the "write a module" exercise until multi-file lands.

---

### CONTENT-04: ch. 9 — Input and Output

**Size:** M · **Has a harness wrinkle — read before starting.**

LYAH ch. 9 is `IO`: `putStrLn`, `getLine`, `do` blocks, `return`, `mapM_`, `when`, `sequence`, `getContents`/`interact`. The current harness compiles a `module Main` test runner that **imports the user's module and compares pure values with `==`**. `IO` actions can't be compared that way, so this chapter needs a decision:

- **Option A — test the pure parts (zero infra).** Most ch. 9 programs are a thin `IO` shell around a pure function (e.g. `interact`-style: a `String -> String` that transforms input). Have the exercise ask for that pure function and test it normally. Teaches the *shape* of IO programs without testing effects. Cheapest; recommended for a first pass.
- **Option B — stdin/expected_output mode (small backend task).** Judge0 natively supports `stdin` + `expected_output` and reports Accepted/Wrong Answer. Add a second eval mode in `backend/src/Judge0.hs` that submits the learner's `main` as `source_code`, feeds `stdin`, and compares `stdout` to `expected_output`. This tests real IO (`getLine`/`putStrLn`) authentically. Needs: a curriculum way to express stdin + expected output, an alternate submission path, and result interpretation for status 4 (Wrong Answer).
- **Option C — capture stdout in-process.** Redirect `stdout` to a handle within the test runner (`hDuplicateTo`) and assert on captured text. Works in one file but is fiddly and GHC-version-sensitive; least preferred.

**Recommendation:** ship a few Option-A exercises for the concepts, and only build Option B if we want authentic `getLine`/`putStrLn` testing. Capture Option B as its own backend story if pursued.

---

### CONTENT-05: ch. 10 — Functionally Solving Problems

**Size:** M · Pure — fits the current harness.

Exercise ideas: a reverse-Polish-notation calculator (`solveRPN :: String -> Double`), and the Heathrow-to-London shortest-path problem (`optimalPath`). Both are pure functions with clear inputs/outputs.

---

### CONTENT-06: ch. 11 — Functors, Applicative Functors and Monoids

**Size:** M · Pure — fits the current harness.

Exercise ideas: write a `Functor` instance for a custom type (`fmap`); use `Applicative` (`pure`, `<*>`) e.g. combining `Maybe`s; `Monoid` via `newtype Sum`/`Product` and `mappend`/`mconcat`; `foldMap`.

---

### CONTENT-07: ch. 12 — A Fistful of Monads

**Size:** M · Pure — fits the current harness.

Exercise ideas: the `Maybe` monad with `>>=` and `do`; the list monad (non-determinism); the knight's-move problem (`canReachIn3`). All pure.

---

### CONTENT-08: ch. 13 — For a Few Monads More

**Size:** M · Pure — fits the current harness.

Exercise ideas: `Writer` (logging, e.g. `gcd'` that records steps); `State` (a stack `push`/`pop`); `Reader`. Use `Control.Monad.Writer`/`State` from `mtl` (confirm availability on the Judge0 image, else model the monads by hand as LYAH does).

---

### CONTENT-09: ch. 14 — Zippers

**Size:** S–M · Pure — fits the current harness.

Exercise ideas: a list zipper (`goForward`/`goBack`); a binary-tree zipper with breadcrumbs (`goLeft`/`goRight`/`goUp`, `modify`). Pure data-structure navigation.
