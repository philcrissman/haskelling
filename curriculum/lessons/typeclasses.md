# Typeclasses

A **typeclass** defines a set of operations that a type can support. Any type that implements those operations is said to have an **instance** of that typeclass. They are similar in concept to interfaces in other languages, but more powerful.

## Show

`Show` is the typeclass for types that can be converted to a `String`. It has one main method:

```haskell
show :: Show a => a -> String
```

Most built-in types already have `Show`: `show 42 = "42"`, `show True = "True"`, `show [1,2,3] = "[1,2,3]"`.

For a custom type, the easiest way to get `Show` is `deriving`:

```haskell
data Color = Red | Green | Blue deriving (Show)

show Red    -- "Red"
show Green  -- "Green"
```

`deriving (Show)` generates an instance automatically, using the constructor names as strings.

## Eq

`Eq` is the typeclass for types that support equality comparison:

```haskell
(==) :: Eq a => a -> a -> Bool
(/=) :: Eq a => a -> a -> Bool
```

Derive it when all constructors and fields already have `Eq`:

```haskell
data Suit = Clubs | Diamonds | Hearts | Spades deriving (Eq)

Clubs == Clubs     -- True
Clubs == Hearts    -- False
```

## Writing instances manually

Sometimes you need custom behaviour. Use `instance` to write your own:

```haskell
data Point = Point Int Int

instance Show Point where
  show (Point x y) = "(" ++ show x ++ ", " ++ show y ++ ")"

instance Eq Point where
  (==) (Point x1 y1) (Point x2 y2) = x1 == x2 && y1 == y2
```

When you implement `Eq`, Haskell derives `/=` automatically as `not (a == b)` — you only need to define `==`.

## Deriving multiple classes

You can derive several classes at once:

```haskell
data Direction = North | South | East | West deriving (Eq, Show, Ord, Enum)
```

Common classes to derive: `Show`, `Eq`, `Ord` (ordering), `Enum` (enumeration), `Bounded` (min/max values).

## Functor and fmap

`Functor` is the typeclass for types that can be "mapped over." Its one method is `fmap`:

```haskell
fmap :: Functor f => (a -> b) -> f a -> f b
```

`Maybe` is a `Functor`. `fmap f (Just x) = Just (f x)`, and `fmap f Nothing = Nothing`:

```haskell
fmap (*2) (Just 5)    -- Just 10
fmap (*2) Nothing     -- Nothing
```

This is useful because it lets you apply a function to an optional value without first checking whether it is `Nothing`. You can also use `<$>` as an infix alias for `fmap`:

```haskell
(*2) <$> Just 5    -- Just 10
```

Lists are also `Functor` instances — `fmap` on a list is the same as `map`.

## Typeclass constraints in type signatures

When a function works for any type that has a certain typeclass, you write the constraint before `=>`:

```haskell
printIt :: Show a => a -> IO ()
printIt x = putStrLn (show x)
```

The `Show a =>` part means: "for any type `a` that has a `Show` instance." Multiple constraints are written in a tuple: `(Show a, Eq a) =>`.

## Further reading

- [Learn You a Haskell — Types and Typeclasses](http://learnyouahaskell.com/types-and-typeclasses#typeclasses-101)
- [`Functor` on Hoogle](https://hoogle.haskell.org/?hoogle=Functor)
