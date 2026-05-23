module ImplementingEq where

data Point = Point Int Int

-- Two Points are equal if both coordinates match.
instance Eq Point where
  (==) a b = undefined