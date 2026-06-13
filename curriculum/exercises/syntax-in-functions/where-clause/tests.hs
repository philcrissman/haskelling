module Main where

import System.Exit (exitFailure, exitSuccess)
import WhereClause

assertEqual :: (Show a, Eq a) => String -> a -> a -> IO Bool
assertEqual lbl got want
  | got == want = do
      putStrLn $ "  PASS: " ++ lbl
      return True
  | otherwise = do
      putStrLn $ "  FAIL: " ++ lbl
      putStrLn $ "    expected: " ++ show want
      putStrLn $ "    got:      " ++ show got
      return False

main :: IO ()
main = do
  results <- sequence
    [ assertEqual "low bmi is underweight" (bmiTell 50 1.8) "underweight"
    , assertEqual "mid bmi is normal" (bmiTell 70 1.85) "normal"
    , assertEqual "higher bmi is overweight" (bmiTell 85 1.75) "overweight"
    , assertEqual "high bmi is obese" (bmiTell 120 1.7) "obese"
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
