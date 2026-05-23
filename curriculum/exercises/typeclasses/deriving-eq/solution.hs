module DerivingEq where

data Suit = Clubs | Diamonds | Hearts | Spades deriving (Eq)

sameSuit :: Suit -> Suit -> Bool
sameSuit a b = a == b