module WhereClause where

-- Given weight (kg) and height (m), return a BMI category.
-- BMI = weight / height ^ 2, and:
--   bmi <= 18.5  -> "underweight"
--   bmi <= 25.0  -> "normal"
--   bmi <= 30.0  -> "overweight"
--   otherwise    -> "obese"
-- Use a `where` binding so bmi is computed once and shared by all the guards.
bmiTell :: Double -> Double -> String
bmiTell weight height = undefined
