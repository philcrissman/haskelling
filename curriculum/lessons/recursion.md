# Recursion

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Recursion**](https://learnyouahaskell.github.io/recursion.html). Read it alongside these exercises.

Haskell has no loops. Instead, functions are defined in terms of themselves — that's recursion. It's the main way you'll process lists and repeat work.

## The shape of a recursive function

A recursive definition has two parts:

- one or more **base cases** that give a direct answer without recursing, and
- a **recursive case** that solves a smaller version of the problem and builds on it.

Pattern matching makes the two cases natural to write. Here's `maximum'`, which finds the largest element of a list:

```haskell
maximum' :: (Ord a) => [a] -> a
maximum' []     = error "maximum of empty list"
maximum' [x]    = x
maximum' (x:xs) = max x (maximum' xs)
```

The base cases handle the empty list (an error) and the single-element list (the element itself). The recursive case takes the head off, finds the maximum of the rest, and keeps whichever is larger. Each recursive call works on a shorter list, so it eventually hits a base case.

## Building lists recursively

Many list functions are written by consing an element onto a recursive result:

```haskell
replicate' :: Int -> a -> [a]
replicate' n x
  | n <= 0    = []
  | otherwise = x : replicate' (n - 1) x
```

Here a guard provides the base case (`n <= 0` gives `[]`) and the recursive case prepends `x` to a list that's one shorter.

## Quicksort

The famous example: sort a list by putting everything smaller than the head before it and everything larger after, recursively sorting each part.

```haskell
quicksort :: (Ord a) => [a] -> [a]
quicksort []     = []
quicksort (x:xs) =
  let smaller = quicksort [a | a <- xs, a <= x]
      larger  = quicksort [a | a <- xs, a > x]
  in smaller ++ [x] ++ larger
```

When you write recursion, always ask: what's the base case, and does each recursive call get closer to it?
