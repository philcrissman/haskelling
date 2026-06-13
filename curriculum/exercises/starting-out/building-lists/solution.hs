module BuildingLists where

surround :: a -> [a] -> [a]
surround x xs = x : xs ++ [x]
