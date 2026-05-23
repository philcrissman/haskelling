module DerivingShow where

data Color = Red | Green | Blue deriving (Show)

colorName :: Color -> String
colorName c = show c