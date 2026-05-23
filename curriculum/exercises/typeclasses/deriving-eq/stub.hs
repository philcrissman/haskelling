module DerivingEq where

-- Add `deriving (Eq)` to enable equality comparison.
data Suit = Clubs | Diamonds | Hearts | Spades

sameSuit :: Suit -> Suit -> Bool
sameSuit a b = undefined