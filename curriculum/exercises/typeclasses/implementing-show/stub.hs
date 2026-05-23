module ImplementingShow where

data Suit = Clubs | Diamonds | Hearts | Spades

instance Show Suit where
  show suit = undefined