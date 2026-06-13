module Typeclasses where

class Describable a where
  describe :: a -> String

data Animal = Dog | Cat | Cow

instance Describable Animal where
  describe a = undefined
