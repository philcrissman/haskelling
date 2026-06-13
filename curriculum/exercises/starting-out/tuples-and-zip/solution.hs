module TuplesAndZip where

pairUp :: [a] -> [b] -> [(a, b)]
pairUp xs ys = zip xs ys
