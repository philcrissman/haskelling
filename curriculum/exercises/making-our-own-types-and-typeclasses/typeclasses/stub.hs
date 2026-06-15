module Typeclasses where

class Describable a where
  describe :: a -> String

data Animal = Dog | Cat | Cow

-- describe should return each animal's sound:
--   Dog -> "Woof"
--   Cat -> "Meow"
--   Cow -> "Moo"
instance Describable Animal where
  describe a = undefined
