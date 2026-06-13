module ListComprehensions where

multiplesOfThree :: [Int] -> [Int]
multiplesOfThree xs = [x | x <- xs, x `mod` 3 == 0]
