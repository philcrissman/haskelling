module ListBasics where

secondElement :: [Int] -> Int
secondElement xs = head (tail xs)