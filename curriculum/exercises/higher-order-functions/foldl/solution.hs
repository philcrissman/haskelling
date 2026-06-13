module Foldl where

reverseList :: [a] -> [a]
reverseList xs = foldl (\acc x -> x : acc) [] xs
