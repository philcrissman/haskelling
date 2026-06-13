module WhereClause where

bmiTell :: Double -> Double -> String
bmiTell weight height
  | bmi <= 18.5 = "underweight"
  | bmi <= 25.0 = "normal"
  | bmi <= 30.0 = "overweight"
  | otherwise   = "obese"
  where bmi = weight / height ^ 2
