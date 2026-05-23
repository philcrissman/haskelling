module WhereClause where

hypotenuse :: Double -> Double -> Double
hypotenuse a b = sqrt (aSquared + bSquared)
  where
    aSquared = a * a
    bSquared = b * b