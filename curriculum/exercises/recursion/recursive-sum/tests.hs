module Main where

import System.Exit (exitFailure, exitSuccess)
import RecursiveSum

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
    [ assertEqual "sums an empty list to 0" (mySum []) (0)
    , assertEqual "sums [1,2,3] to 6" (mySum [1,2,3]) (6)
    , assertEqual "sums [10,20,30] to 60" (mySum [10,20,30]) (60)
    , assertEqual "sums a single-element list" (mySum [7]) (7)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
