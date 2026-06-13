module LetExpression where

boxMetric :: Int -> Int -> Int
boxMetric w h =
  let area      = w * h
      perimeter = 2 * (w + h)
  in area + perimeter
