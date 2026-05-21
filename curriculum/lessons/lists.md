# Lists

## The list type

A list in Haskell is a sequence of values all of the same type. The type of a list of `Int` is `[Int]`. Literal syntax uses square brackets with comma-separated values:

```haskell
[1, 2, 3]       :: [Int]
["a", "b", "c"] :: [String]
[]              :: [a]      -- the empty list; works for any element type
```

`String` is actually `[Char]` — a list of characters.

## head and tail

`head` returns the first element; `tail` returns everything after the first element:

```haskell
head [1,2,3]    -- 1
tail [1,2,3]    -- [2,3]
tail [42]       -- []
```

Both crash on an empty list, so use them only when you know the list is non-empty (or use pattern matching instead — see the Pattern Matching chapter).

## Range syntax

`[a..b]` generates a list from `a` to `b` inclusive. If `a > b` the result is `[]`:

```haskell
[1..5]      -- [1,2,3,4,5]
[1..1]      -- [1]
[1..0]      -- []
```

You can specify a step by giving the first two elements:

```haskell
[1,3..10]   -- [1,3,5,7,9]
[10,8..1]   -- [10,8,6,4,2]
```

## The cons operator (:)

`:` (pronounced "cons") prepends a single element to a list:

```haskell
1 : [2,3]    -- [1,2,3]
1 : []       -- [1]
```

The left side of `:` is an element; the right side is a list. `++` concatenates two lists:

```haskell
[1,2] ++ [3,4]    -- [1,2,3,4]
```

Under the hood, `[1,2,3]` is syntactic sugar for `1 : 2 : 3 : []`.

## map

`map` applies a function to every element of a list and returns a new list of results:

```haskell
map (*2) [1,2,3]          -- [2,4,6]
map negate [1,-2,3]       -- [-1,2,-3]
map length ["hi","hello"] -- [2,5]
```

The type is `map :: (a -> b) -> [a] -> [b]`. The input and output element types can differ.

## filter

`filter` keeps only the elements for which a predicate returns `True`:

```haskell
filter even [1,2,3,4,5,6]    -- [2,4,6]
filter (>3) [1,2,3,4,5]      -- [4,5]
```

The type is `filter :: (a -> Bool) -> [a] -> [a]`.

## Useful Prelude functions

| Function | Type | Description |
|----------|------|-------------|
| `length` | `[a] -> Int` | number of elements |
| `null` | `[a] -> Bool` | `True` if empty |
| `reverse` | `[a] -> [a]` | reverse the list |
| `take n` | `[a] -> [a]` | first `n` elements |
| `drop n` | `[a] -> [a]` | all but first `n` elements |
| `sum` | `[Int] -> Int` | sum of elements |
| `zip` | `[a] -> [b] -> [(a,b)]` | pair elements from two lists |

## Further reading

- [Haskell `Data.List` on Hoogle](https://hoogle.haskell.org/?hoogle=Data.List)
- [Learn You a Haskell — An Introduction to Lists](http://learnyouahaskell.com/starting-out#an-intro-to-lists)
