# Syntax in Functions

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Syntax in Functions**](https://learnyouahaskell.github.io/syntax-in-functions.html). Read it alongside these exercises.

This chapter is about the different ways to write the body of a function: pattern matching, guards, `where`, `let`, and `case`.

## Pattern matching

You can define a function as several equations, each matching a different shape of input. Haskell tries them top to bottom. `_` matches anything:

```haskell
sayMe :: Int -> String
sayMe 1 = "one"
sayMe 2 = "two"
sayMe _ = "something else"
```

Patterns work on tuples and lists too. `(x:xs)` matches a non-empty list, binding its head to `x` and tail to `xs`:

```haskell
addVectors :: (Double, Double) -> (Double, Double) -> (Double, Double)
addVectors (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)

firstOrZero :: [Int] -> Int
firstOrZero []     = 0
firstOrZero (x:_)  = x
```

Always handle every case — a missing pattern is a runtime error.

## Guards

Guards test boolean conditions to choose a result. Each guard starts with `|`, and `otherwise` is the catch-all:

```haskell
gradeLetter :: Int -> Char
gradeLetter score
  | score >= 90 = 'A'
  | score >= 80 = 'B'
  | otherwise   = 'F'
```

## where

A `where` block names intermediate values, computed once and visible to all the guards of a definition:

```haskell
bmiTell :: Double -> Double -> String
bmiTell weight height
  | bmi <= 18.5 = "underweight"
  | bmi <= 25.0 = "normal"
  | otherwise   = "heavier"
  where bmi = weight / height ^ 2
```

## let

A `let … in` expression binds names that are in scope only within the expression after `in`:

```haskell
boxMetric :: Int -> Int -> Int
boxMetric w h =
  let area      = w * h
      perimeter = 2 * (w + h)
  in area + perimeter
```

The difference from `where`: `let` is an expression and can appear almost anywhere, while `where` is attached to a function definition.

## case

A `case` expression pattern matches on a value inline, anywhere an expression is allowed:

```haskell
describeList :: [a] -> String
describeList xs = "The list is " ++ case xs of
  []  -> "empty."
  [_] -> "a singleton list."
  _   -> "a longer list."
```

Function pattern matching is really just syntactic sugar for a `case` expression.
