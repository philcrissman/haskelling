# Recursion

Haskell has no `for` or `while` loops. Repetition is expressed through **recursion** — a function that calls itself.

## Base case and recursive case

Every recursive function needs at least one **base case** (which returns without recursing) and one **recursive case** (which makes a smaller call). Without a base case, recursion never terminates.

```haskell
factorial :: Integer -> Integer
factorial 0 = 1                          -- base case
factorial n = n * factorial (n - 1)     -- recursive case
```

Evaluation: `factorial 3` → `3 * factorial 2` → `3 * 2 * factorial 1` → `3 * 2 * 1 * factorial 0` → `3 * 2 * 1 * 1` = 6.

## Recursion over lists

Lists are defined recursively — a list is either empty `[]` or a head cons'd onto a tail `(x:xs)`. Pattern matching on that structure drives the recursion naturally:

```haskell
mySum :: [Int] -> Int
mySum []     = 0              -- base case: empty list sums to 0
mySum (x:xs) = x + mySum xs  -- recursive case: add head to sum of tail
```

The pattern `(x:xs)` binds the first element to `x` and the rest to `xs`. Every recursive call works on a shorter list, so the base case is always eventually reached.

```haskell
myLength :: [a] -> Int
myLength []     = 0
myLength (_:xs) = 1 + myLength xs   -- _ ignores the head value
```

## Reversing a list

Naïve reverse: recurse to the end, then append the head at the back:

```haskell
myReverse :: [a] -> [a]
myReverse []     = []
myReverse (x:xs) = myReverse xs ++ [x]
```

This works but is O(n²) because `++` copies the list each time.

## Tail recursion with an accumulator

A function is **tail recursive** when the recursive call is the very last thing it does — there is nothing left to do when it returns. GHC optimises tail calls into loops, avoiding stack growth.

The trick is an **accumulator** argument that collects the result as you go:

```haskell
myReverse :: [a] -> [a]
myReverse xs = go xs []
  where
    go []     acc = acc           -- done: return what we have accumulated
    go (x:xs) acc = go xs (x:acc) -- prepend x to acc, recurse on tail
```

`go` is tail recursive because `go xs (x:acc)` is the last thing in the recursive case. The accumulator starts empty and grows with each step; when the input is exhausted, the accumulator holds the result.

This pattern is common: a public-facing function delegates to an internal `go` (or `loop`, or the same name with extra args) that carries the accumulator.

## Thinking recursively

Ask three questions:
1. **What is the simplest input?** That is your base case.
2. **How can I express the answer for input `n` in terms of the answer for something smaller?** That is your recursive case.
3. **Does every path eventually reach the base case?** If not, you have infinite recursion.

## Further reading

- [Learn You a Haskell — Recursion](http://learnyouahaskell.com/recursion)
- [`foldl` and `foldr` on Hoogle](https://hoogle.haskell.org/?hoogle=foldl) — generalised recursion over lists
