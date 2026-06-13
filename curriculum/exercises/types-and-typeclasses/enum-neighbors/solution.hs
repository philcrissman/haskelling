module EnumNeighbors where

neighbors :: Char -> (Char, Char)
neighbors c = (pred c, succ c)
