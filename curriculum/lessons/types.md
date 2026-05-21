# Types

## Type signatures

Every Haskell expression has a type. You can write an explicit **type signature** on the line above a definition:

```haskell
square :: Int -> Int
square x = x * x
```

The `::` is read "has type." Type signatures are optional — GHC can infer them — but writing them is good practice: they document intent and produce clearer error messages.

Arrow `->` is right-associative, so `Int -> Int -> Int` means `Int -> (Int -> Int)`: a function that takes an `Int` and returns a function from `Int` to `Int` (currying). For reading purposes, think of it as "takes two `Int`s, returns an `Int`."

## The Maybe type

`Maybe a` represents an optional value — either `Just x` (a value is present) or `Nothing` (no value):

```haskell
data Maybe a = Nothing | Just a
```

This is the safe alternative to null. Instead of crashing on "no value", you pattern match:

```haskell
safeHead :: [Int] -> Maybe Int
safeHead []    = Nothing
safeHead (x:_) = Just x
```

To get the value out, use `fromMaybe` from `Data.Maybe`:

```haskell
import Data.Maybe (fromMaybe)

fromMaybe 0 (Just 5)    -- 5
fromMaybe 0 Nothing     -- 0
```

`fromMaybe default maybeValue` returns the wrapped value, or `default` if it is `Nothing`.

## Tuples

A tuple groups a fixed number of values of potentially different types:

```haskell
(1, "hello")   :: (Int, String)
(True, 3, 'x') :: (Bool, Int, Char)
```

The standard library provides `fst` and `snd` for pairs, but pattern matching is more general:

```haskell
fst (1, 2)    -- 1
snd (1, 2)    -- 2

-- or with pattern matching:
addPair :: (Int, Int) -> Int
addPair (x, y) = x + y
```

Unlike lists, each position in a tuple can have a different type, and the length is fixed at compile time.

## Custom data types

`data` defines a new type with one or more **constructors**:

```haskell
data Color = Red | Green | Blue
```

This is a **sum type** (also called an algebraic data type). `Color` has exactly three values. Constructors can also carry data:

```haskell
data Shape = Circle Double      -- radius
           | Rectangle Double Double  -- width, height
```

Add `deriving (Eq, Show)` to get equality comparison and string conversion for free:

```haskell
data Direction = North | South | East | West deriving (Eq, Show)
```

Without `deriving (Show)`, you cannot print a value of that type. Without `deriving (Eq)`, you cannot compare two values with `==`.

Pattern match on constructors the same way you match on other values:

```haskell
area :: Shape -> Double
area (Circle r)      = 3.14159 * r * r
area (Rectangle w h) = w * h
```

## Further reading

- [Haskell `Data.Maybe` on Hoogle](https://hoogle.haskell.org/?hoogle=Data.Maybe)
- [Learn You a Haskell — Types and Typeclasses](http://learnyouahaskell.com/types-and-typeclasses)
