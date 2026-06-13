module BooleanLogic where

exactlyOne :: Bool -> Bool -> Bool
exactlyOne a b = (a || b) && not (a && b)
