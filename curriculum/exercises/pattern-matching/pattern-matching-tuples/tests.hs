module Main where

import System.Exit (exitFailure, exitSuccess)
import PatternMatchingTuples

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
    [ assertEqual "adds (1, 2)" (addPair (1, 2)) (3)
    , assertEqual "adds (0, 0)" (addPair (0, 0)) (0)
    , assertEqual "adds negative and positive" (addPair (-5, 10)) (5)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
