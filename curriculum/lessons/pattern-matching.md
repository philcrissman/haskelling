# Pattern Matching

Pattern matching lets you branch on the **shape** of a value and bind its parts to names. It is one of the most important tools in Haskell.

## Matching on lists

List patterns cover three common shapes:

```haskell
describe :: [Int] -> String
describe []     = "empty"
describe [x]    = "exactly one element"
describe (x:xs) = "at least two elements"
```

- `[]` matches the empty list
- `[x]` matches a list with exactly one element, binding it to `x`
- `(x:xs)` matches a non-empty list, binding the head to `x` and the tail to `xs`
- `_` in any position ignores that part of the value

Patterns are tried top to bottom; the first match wins.

## Matching on Maybe

```haskell
showMaybe :: Maybe Int -> String
showMaybe Nothing  = "nothing here"
showMaybe (Just n) = "got " ++ show n
```

`Just n` matches a `Just` value and binds the inner value to `n`. This is the idiomatic way to unwrap a `Maybe` when you need to do something with the value.

## Case expressions

`case` brings pattern matching inside a function body, on any expression:

```haskell
classify :: Int -> String
classify n = case compare n 0 of
  LT -> "negative"
  EQ -> "zero"
  GT -> "positive"
```

`compare a b :: Ordering` returns `LT`, `EQ`, or `GT`. `case` is useful when you want to branch mid-expression rather than writing multiple top-level equations.

## Guards

Guards are a readable alternative to chained `if/then/else`. They follow the function arguments and are checked top to bottom:

```haskell
bmiCategory :: Double -> String
bmiCategory bmi
  | bmi < 18.5 = "Underweight"
  | bmi < 25.0 = "Normal"
  | bmi < 30.0 = "Overweight"
  | otherwise  = "Obese"
```

`otherwise` is just `True` — it acts as the catch-all. Unlike `if`, guards do not require an else branch, but GHC will warn you if no guard can match.

You can combine guards with pattern matching — different equations handle different shapes, and guards refine within an equation:

```haskell
describeList :: [a] -> String
describeList []  = "empty"
describeList [_] = "singleton"
describeList xs
  | length xs < 5 = "short"
  | otherwise     = "long"
```

## Matching on tuples

Tuples are destructured by writing the pattern directly in the argument position:

```haskell
swap :: (a, b) -> (b, a)
swap (x, y) = (y, x)

firstAndLast :: (a, b, c) -> (a, c)
firstAndLast (x, _, z) = (x, z)
```

`_` ignores the middle element.

## Exhaustiveness

GHC checks that your patterns cover all possible cases. If you write:

```haskell
f :: Bool -> String
f True = "yes"
```

GHC warns that `False` is not handled. Always handle every constructor, or use a catch-all `_`.

## Further reading

- [Learn You a Haskell — Syntax in Functions](http://learnyouahaskell.com/syntax-in-functions)
- [`Ordering` on Hoogle](https://hoogle.haskell.org/?hoogle=Ordering)
