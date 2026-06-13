module Main where

import System.Exit (exitFailure, exitSuccess)
import BuildingLists

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
    [ assertEqual "wraps a list of ints" (surround (0 :: Int) [1, 2, 3]) [0, 1, 2, 3, 0]
    , assertEqual "wraps a string" (surround 'x' "yz") "xyzx"
    , assertEqual "wraps an empty list" (surround (1 :: Int) []) [1, 1]
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
