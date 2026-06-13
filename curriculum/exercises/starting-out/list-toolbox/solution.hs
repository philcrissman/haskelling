module ListToolbox where

dropFirstAndLast :: [a] -> [a]
dropFirstAndLast xs = init (tail xs)
