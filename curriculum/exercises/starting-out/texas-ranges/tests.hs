module Main where

import System.Exit (exitFailure, exitSuccess)
import TexasRanges

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
    [ assertEqual "evens up to 10" (evensTo 10) [2, 4, 6, 8, 10]
    , assertEqual "stops below an odd bound" (evensTo 7) [2, 4, 6]
    , assertEqual "empty when below 2" (evensTo 1) []
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
