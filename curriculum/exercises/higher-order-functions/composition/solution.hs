module Composition where

countEvens :: [Int] -> Int
countEvens = length . filter even
