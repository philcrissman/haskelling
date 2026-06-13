module Main where

import System.Exit (exitFailure, exitSuccess)
import Filtering

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
    [ assertEqual "keeps the evens" (onlyEvens [1, 2, 3, 4, 5, 6]) [2, 4, 6]
    , assertEqual "no evens" (onlyEvens [1, 3, 5]) []
    , assertEqual "empty list" (onlyEvens []) []
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
