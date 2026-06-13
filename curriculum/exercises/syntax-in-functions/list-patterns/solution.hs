module ListPatterns where

firstOrZero :: [Int] -> Int
firstOrZero []    = 0
firstOrZero (x:_) = x
