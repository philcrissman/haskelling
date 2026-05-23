module TailRecursion where

-- Reverse a list using a tail-recursive helper with an accumulator.
myReverse :: [a] -> [a]
myReverse xs = go xs []
  where
    go remaining acc = undefined