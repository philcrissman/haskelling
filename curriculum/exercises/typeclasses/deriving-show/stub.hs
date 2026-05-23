module DerivingShow where

-- Add `deriving (Show)` to this data declaration.
data Color = Red | Green | Blue

colorName :: Color -> String
colorName c = show c