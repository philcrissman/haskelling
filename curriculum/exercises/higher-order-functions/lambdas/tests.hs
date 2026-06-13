module Main where

import System.Exit (exitFailure, exitSuccess)
import Lambdas

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
    [ assertEqual "triples each element" (scaleAll 3 [1, 2, 3]) [3, 6, 9]
    , assertEqual "scales by zero" (scaleAll 0 [1, 2]) [0, 0]
    , assertEqual "empty list" (scaleAll 2 []) []
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
