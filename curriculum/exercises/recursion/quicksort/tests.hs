module Main where

import System.Exit (exitFailure, exitSuccess)
import Quicksort

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
    [ assertEqual "sorts ints" (quicksort [3, 1, 4, 1, 5, 9, 2 :: Int]) [1, 1, 2, 3, 4, 5, 9]
    , assertEqual "sorts a string" (quicksort "haskell") "aehklls"
    , assertEqual "empty list" (quicksort ([] :: [Int])) []
    , assertEqual "keeps duplicates" (quicksort [5, 5, 3 :: Int]) [3, 5, 5]
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
