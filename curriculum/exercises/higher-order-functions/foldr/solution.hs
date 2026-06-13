module Foldr where

sumList :: [Int] -> Int
sumList xs = foldr (+) 0 xs
