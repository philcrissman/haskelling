module ImplementingShow where

data Suit = Clubs | Diamonds | Hearts | Spades

instance Show Suit where
  show Clubs    = "\9827"
  show Diamonds = "\9830"
  show Hearts   = "\9829"
  show Spades   = "\9824"