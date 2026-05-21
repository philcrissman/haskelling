# Basics

## Functions

A Haskell program is a collection of functions. The simplest function takes no arguments and just returns a value:

```haskell
greeting :: String
greeting = "Hello, World!"
```

The first line is the **type signature** — `greeting` has type `String`. The second line is the **definition**.

Functions that take arguments list them before the `=`:

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

The type `Int -> Int -> Int` reads: "takes an Int, then another Int, returns an Int." To call a function, write its name followed by its arguments separated by spaces — no parentheses needed:

```haskell
add 2 3    -- gives 5
```

## Strings

A `String` in Haskell is written with double quotes: `"Hello"`. Strings can be joined with `++`:

```haskell
"Hello, " ++ "World!"    -- gives "Hello, World!"
```

## Numbers

`Int` is a fixed-precision integer. The usual arithmetic operators work: `+`, `-`, `*`. There is no implicit conversion between types — `Int` and `Integer` (arbitrary precision) are distinct.

## Bool

The type `Bool` has two values: `True` and `False`. Comparison operators return `Bool`:

```haskell
5 > 3      -- True
2 == 2     -- True
1 /= 1     -- False   (/= means "not equal")
10 >= 10   -- True
```

Logical operators: `&&` (and), `||` (or), `not`.

## if/then/else

In Haskell, `if` is an **expression** — it always returns a value, and both branches must have the same type:

```haskell
absolute :: Int -> Int
absolute n = if n < 0 then -n else n
```

There is no `if` without `else`. The `else` branch is mandatory.

## undefined

You will see `undefined` in exercise stubs. It is a placeholder that compiles but crashes at runtime. Replace it with your actual implementation.

## Further reading

- [Haskell `Prelude` on Hoogle](https://hoogle.haskell.org/?hoogle=Prelude) — search for any function mentioned here
- [Learn You a Haskell — Starting Out](http://learnyouahaskell.com/starting-out)
