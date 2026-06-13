# Starting Out

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Starting Out**](https://learnyouahaskell.github.io/starting-out.html). Read it alongside these exercises; everything you need to solve them is in that chapter.

This chapter covers the very first things you can do in Haskell: arithmetic, booleans, simple functions, lists, ranges, list comprehensions, and tuples.

## Arithmetic and booleans

Haskell does arithmetic the way you'd expect. Note that negative numbers usually need parentheses:

```haskell
2 + 15      -- 17
49 * 100    -- 4900
5 / 2       -- 2.5
doubleMe x = x + x
```

Booleans use `&&` (and), `||` (or), and `not`. You compare values with `==` (equal) and `/=` (not equal):

```haskell
True && False   -- False
not (True || False)  -- False
5 == 5          -- True
5 /= 5          -- False
```

## Lists

Lists are the workhorse of Haskell. You build them with `:` (cons, prepend one element) and join them with `++` (append):

```haskell
1 : [2, 3]      -- [1, 2, 3]
[1, 2] ++ [3, 4]  -- [1, 2, 3, 4]
```

Some useful list functions: `head`, `tail`, `last`, `init`, `length`, `reverse`, `take`, `drop`, `maximum`, `minimum`, `sum`, `product`, and `elem`.

```haskell
head [5, 4, 3]  -- 5
tail [5, 4, 3]  -- [4, 3]
init [5, 4, 3]  -- [5, 4]
```

## Ranges

Ranges are a quick way to make lists of things that can be enumerated. Give a step by listing the first two elements:

```haskell
[1 .. 5]        -- [1, 2, 3, 4, 5]
[2, 4 .. 10]    -- [2, 4, 6, 8, 10]
['a' .. 'e']    -- "abcde"
```

## List comprehensions

A list comprehension builds a list from one or more source lists, optionally filtered by a predicate:

```haskell
[x * 2 | x <- [1 .. 5]]                 -- [2, 4, 6, 8, 10]
[x | x <- [1 .. 20], x `mod` 3 == 0]    -- [3, 6, 9, 12, 15, 18]
```

## Tuples

A tuple groups a fixed number of values, which may be of different types. Pairs are the most common; `fst` and `snd` get the first and second element, and `zip` pairs up two lists:

```haskell
fst (8, 11)              -- 8
snd (8, 11)              -- 11
zip [1, 2, 3] "abc"      -- [(1, 'a'), (2, 'b'), (3, 'c')]
```
