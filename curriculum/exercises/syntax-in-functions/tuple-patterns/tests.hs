module Main where

import System.Exit (exitFailure, exitSuccess)
import TuplePatterns

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
    [ assertEqual "adds two vectors" (addVectors (1, 2) (3, 4)) (4, 6)
    , assertEqual "adds with a negative" (addVectors (0, 0) (5, -2)) (5, -2)
    , assertEqual "adds halves" (addVectors (1.5, 2.5) (0.5, 0.5)) (2.0, 3.0)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
