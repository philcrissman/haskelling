# Basics

## Functions

Haskell is a functional programming language; among other things, this means that most of what we do when we write Haskell is defining functions. The simplest function takes no arguments and just returns a value:

```haskell
greeting :: String
greeting = "Hello, World!"
```

The first line is the **type signature** — `greeting` has the type `String`. The
second line is the **definition**.

Type signatures are optional—Haskell is able to infer types in most cases—but almost every book about learning Haskell will encourage you to write them anyways. They can be documentation, and they help the compiler catch mistakes.

For what it's worth: this isn't assignment, it's more like a definition. `greeting = "Hello, World!"` means `greeting` *is* `"Hello, World!"` In Haskell, you define things; you don't mutate them.

Functions that take arguments list them before the `=`:

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

The type `Int -> Int -> Int` reads: "takes an Int, then another Int, returns an
Int." The arrow notation reflects something fundamental about how Haskell
functions work — we'll get to that soon. For now, read each `->` as separating
inputs from output, with the last type being the return type.

To call a function, write its name followed by its arguments separated by
spaces:

```haskell
add 2 3    -- gives 5
```

Note there's no parens, or commas, above. If you're coming from another language, you might be tempted to write `add(2, 3)`, but that's not needed here. Parentheses
are only for grouping: `add (1 + 1) 3`.

## Strings

A `String` in Haskell is written with double quotes: `"Hello"`. Join strings
with `++`:

```haskell
"Hello, " ++ "World!"    -- "Hello, World!"
```

That's `++`, not `+`. The `+` operator is only for numbers.

One thing you may run into: `String` and `[Char]` are the
same type. `String` is just a type alias for a list of characters. If the
compiler says `[Char]` where you expected `String`, that's why.

## Numbers

`Int` is a fixed-precision integer. It's machine-word-sized, so it can overflow
on very large values. `Integer` gives you arbitrary precision at the cost of
some performance. For the exercises here, `Int` is fine.

The usual arithmetic operators work: `+`, `-`, `*`. There's no implicit
conversion between numeric types — if a function expects an `Int`, you can't
pass it a `Double` without converting explicitly. This is stricter than most
languages, but it eliminates a whole category of subtle bugs.

## Bool

`Bool` has two values: `True` and `False`. Comparison operators return `Bool`:

```haskell
5 > 3      -- True
2 == 2     -- True
1 /= 1     -- False   (/= means "not equal")
10 >= 10   -- True
```

`==` in Haskell is always value equality. There's no reference equality to
worry about.

Logical operators: `&&` (and), `||` (or), `not`.

## if/then/else

In Haskell, `if` is an **expression** — it produces a value:

```haskell
absolute :: Int -> Int
absolute n = if n < 0 then -n else n
```

Because `if` must produce a value, both branches are required and must have the
same type. There's no `if` without `else`. This, for example, is a type error:

```haskell
if True then "hello" else 42   -- String vs. Int: rejected
```

Both branches have to agree on a type. The compiler enforces this.

## undefined

You'll see `undefined` in exercise stubs. It's a placeholder — it compiles, but
crashes if it's ever evaluated. Replace it with your actual implementation.

## Further reading

- [Haskell `Prelude` on Hoogle](https://hoogle.haskell.org/?hoogle=Prelude) —
  search for any function mentioned here
- [Learn You a Haskell — Starting Out](http://learnyouahaskell.com/starting-out)
