module AlgebraicDataTypes where

data Shape = Square Double | Rectangle Double Double

area :: Shape -> Double
area (Square s)      = s * s
area (Rectangle w h) = w * h
