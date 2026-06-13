# Making Our Own Types and Typeclasses

> 📖 **Reading:** This chapter follows [*Learn You a Haskell for Great Good!* — **Making Our Own Types and Typeclasses**](https://learnyouahaskell.github.io/making-our-own-types-and-typeclasses.html). Read it alongside these exercises.

So far you've used Haskell's built-in types. Now you'll define your own.

## Algebraic data types

The `data` keyword defines a new type. After the `=` come the **value constructors**, separated by `|`. A constructor can carry fields:

```haskell
data Shape = Square Double | Rectangle Double Double
```

You work with such values by pattern matching on the constructors:

```haskell
area :: Shape -> Double
area (Square s)      = s * s
area (Rectangle w h) = w * h
```

## Record syntax

When a type has several named fields, record syntax gives you accessor functions for free and a clearer way to construct and update values:

```haskell
data Person = Person { name :: String, age :: Int }

birthday :: Person -> Person
birthday p = p { age = age p + 1 }   -- record update
```

`name p` and `age p` read fields; `p { age = ... }` makes a copy with one field changed.

## Type parameters

A type can be parameterized, just like `Maybe a`. The parameter `a` stands for any type:

```haskell
data Optional a = None | Some a
```

## Derived instances

Adding a `deriving` clause makes Haskell generate standard instances for you:

```haskell
data Priority = Low | Medium | High
  deriving (Eq, Ord, Show, Enum, Bounded)
```

Now `Priority` values can be compared (`Eq`, `Ord`), shown (`Show`), enumerated (`Enum`), and have `minBound`/`maxBound` (`Bounded`).

## Type synonyms

`type` introduces a synonym — a new name for an existing type, purely for readability:

```haskell
type PhoneBook = [(String, String)]
```

## Recursive data types

A type can refer to itself, which is how you build structures like trees:

```haskell
data Tree a = Leaf | Node (Tree a) a (Tree a)
```

Functions over them recurse on the sub-structures, with the non-recursive constructor as the base case.

## Typeclasses

A typeclass defines an interface; an `instance` says how a particular type implements it:

```haskell
class Describable a where
  describe :: a -> String

instance Describable Animal where
  describe Dog = "Woof"
  describe Cat = "Meow"
```
