module Lambdas where

scaleAll :: Int -> [Int] -> [Int]
scaleAll n = map (\x -> x * n)
