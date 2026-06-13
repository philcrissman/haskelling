module Main where

import System.Exit (exitFailure, exitSuccess)
import ListComprehensions

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
    [ assertEqual "keeps multiples of 3 from 1..10" (multiplesOfThree [1 .. 10]) [3, 6, 9]
    , assertEqual "keeps only the divisible ones" (multiplesOfThree [3, 5, 9, 12]) [3, 9, 12]
    , assertEqual "none divisible" (multiplesOfThree [1, 2, 4]) []
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
