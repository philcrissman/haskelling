module TailRecursion where

myReverse :: [a] -> [a]
myReverse xs = go xs []
  where
    go []     acc = acc
    go (x:xs) acc = go xs (x:acc)