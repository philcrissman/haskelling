# Functions

## Lambda expressions

A **lambda** is an anonymous function written with a backslash:

```haskell
\x -> x * 2        -- a function that doubles its argument
\x y -> x + y      -- a function that adds two arguments
```

Lambdas are values. You can assign one to a name:

```haskell
double :: Int -> Int
double = \x -> x * 2
```

This is exactly equivalent to `double x = x * 2`. Lambdas are most useful when you need a small function inline and don't want to name it.

## where clauses

`where` introduces local bindings that are visible only within the function they belong to. Useful for naming intermediate values:

```haskell
bmi :: Double -> Double -> Double
bmi weight height = weight / heightSquared
  where
    heightSquared = height * height
```

`where` bindings are indented and appear after the function body. You can define multiple bindings, and they can refer to each other.

## let expressions

`let ... in ...` is the expression form of the same idea — name a value, then use it:

```haskell
circleArea :: Double -> Double
circleArea r =
  let pi'   = 3.14159
      r2    = r * r
  in  pi' * r2
```

`let` is an expression, so it can appear anywhere a value is expected, including inside `if` branches, `case` arms, or other `let` expressions. `where` is attached to a whole equation; `let` is embedded in an expression. Both are common — use whichever reads more clearly.

## Function composition

The `.` operator composes two functions. `(f . g) x` means `f (g x)` — apply `g` first, then `f`:

```haskell
shout :: String -> String
shout = reverse . map toUpper    -- applies map toUpper, then reverse
```

Composition is right-to-left. Read `negate . abs` as "abs, then negate."

## Partial application and operator sections

Every Haskell function is **curried** — applying it to fewer arguments than it expects returns a new function:

```haskell
add :: Int -> Int -> Int
add x y = x + y

addThree :: Int -> Int
addThree = add 3    -- addThree y = 3 + y
```

Operators support a shorthand called **sections** — wrap the operator and one argument in parentheses:

```haskell
(+5)     -- \x -> x + 5
(*2)     -- \x -> x * 2
(10-)    -- \x -> 10 - x   (argument on the right of the operator)
```

Sections are handy with `map` and `filter`:

```haskell
map (*2) [1,2,3]      -- [2,4,6]
filter (>0) [-1,0,1]  -- [1]
```

## Further reading

- Search Hoogle for [`(.)`](https://hoogle.haskell.org/?hoogle=(.)) and [`flip`](https://hoogle.haskell.org/?hoogle=flip)
- [Learn You a Haskell — Higher Order Functions](http://learnyouahaskell.com/higher-order-functions)
