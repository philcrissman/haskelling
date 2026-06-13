# Types and Typeclasses

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Types and Typeclasses**](https://learnyouahaskell.github.io/types-and-typeclasses.html). Read it alongside these exercises.

Haskell has a static type system: the type of every expression is known at compile time. This chapter is about reading those types and understanding the typeclasses that group them.

## Reading types

In GHCi you can ask for the type of any expression with `:t`:

```haskell
:t 'a'        -- 'a' :: Char
:t True       -- True :: Bool
:t "hello"    -- "hello" :: [Char]
:t (True, 'a')  -- (True, 'a') :: (Bool, Char)
```

Functions have types too, and it's good practice to write them out. The last type in the arrow chain is the return type:

```haskell
addThree :: Int -> Int -> Int -> Int
addThree x y z = x + y + z
```

Common types include `Int`, `Integer`, `Float`, `Double`, `Bool`, and `Char`.

## Type variables

When a function works on any type, its signature uses a lowercase **type variable** instead of a concrete type. These are polymorphic functions:

```haskell
fst :: (a, b) -> a
head :: [a] -> a
```

`a` and `b` can stand for any type, so `fst` works on a pair of any two types.

## Typeclasses

A **typeclass** is an interface that defines some behavior. If a type is an instance of a class, it supports the behavior the class describes. A class constraint appears before a `=>` in a type signature — for example `(==) :: Eq a => a -> a -> Bool` reads "for any type `a` that is an instance of `Eq`."

Some classes you'll use right away:

- **`Eq`** — supports `==` and `/=`.
- **`Ord`** — supports ordering. `compare` returns an `Ordering` (`LT`, `EQ`, or `GT`); `<`, `>`, `min`, and `max` come from here too.
- **`Show`** — can be turned into a `String` with `show`.
- **`Read`** — can be parsed from a `String` with `read` (you usually annotate the result type so Haskell knows what to read).
- **`Enum`** — sequentially ordered types; supports `succ` and `pred`.
- **`Bounded`** — has a `minBound` and `maxBound`.
- **`Num`** — numeric types. `fromIntegral` converts an integral number into a more general number type.

```haskell
compare 3 5       -- LT
succ 'a'          -- 'b'
show 42           -- "42"
(read "5" :: Int) -- 5
fromIntegral (length [1,2,3]) :: Double  -- 3.0
```
