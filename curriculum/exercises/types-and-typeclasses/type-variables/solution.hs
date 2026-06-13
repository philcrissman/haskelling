module TypeVariables where

swapPair :: (a, b) -> (b, a)
swapPair t = (snd t, fst t)
