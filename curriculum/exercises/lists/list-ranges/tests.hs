module Main where

import System.Exit (exitFailure, exitSuccess)
import ListRanges

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
    [ assertEqual "returns [1..5] for n=5" (oneToN 5) ([1,2,3,4,5])
    , assertEqual "returns [1] for n=1" (oneToN 1) ([1])
    , assertEqual "returns [] for n=0" (oneToN 0) ([])
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
