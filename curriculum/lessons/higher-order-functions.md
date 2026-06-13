# Higher Order Functions

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Higher Order Functions**](https://learnyouahaskell.github.io/higher-order-functions.html). Read it alongside these exercises.

A higher-order function is one that takes a function as an argument or returns a function. They're the heart of how you express computation in Haskell.

## Curried functions and partial application

Every function in Haskell really takes one argument and returns a function. So you can apply a function to *some* of its arguments and get back a function waiting for the rest:

```haskell
add :: Int -> Int -> Int
add x y = x + y

addFive :: Int -> Int
addFive = add 5      -- partial application
```

Operators can be partially applied with **sections**: `(+ 3)`, `(* 2)`, `(> 0)`.

## Functions as arguments

A function can take another function as a parameter. The type `(a -> a)` in a signature means "a function from `a` to `a`":

```haskell
applyTwice :: (a -> a) -> a -> a
applyTwice f x = f (f x)
```

## map and filter

Two workhorses. `map` applies a function to every element; `filter` keeps the elements that satisfy a predicate:

```haskell
map (* 2) [1, 2, 3]        -- [2, 4, 6]
filter even [1, 2, 3, 4]   -- [2, 4]
```

## Lambdas

A lambda is an anonymous function, written `\args -> body`. They're handy for passing a one-off function to `map` or `filter`:

```haskell
map (\x -> x * x) [1, 2, 3]   -- [1, 4, 9]
```

## Folds

A fold reduces a list to a single value by repeatedly applying a function with an accumulator. `foldr` consumes from the right, `foldl` from the left:

```haskell
foldr (+) 0 [1, 2, 3]                    -- 6
foldl (\acc x -> x : acc) [] [1, 2, 3]   -- [3, 2, 1]
```

The accumulator starts at the second argument; the lambda combines the running accumulator with each element.

## Function composition

`(.)` glues two functions into one — `(f . g) x` means `f (g x)`. It's great for building functions point-free:

```haskell
countEvens :: [Int] -> Int
countEvens = length . filter even
```
