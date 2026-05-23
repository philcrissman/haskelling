module Main where

import System.Exit (exitFailure, exitSuccess)
import FunctionComposition

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
    [ assertEqual "absoluteThenNegate 5" (absoluteThenNegate 5) (-5)
    , assertEqual "absoluteThenNegate (-3)" (absoluteThenNegate (-3)) (-3)
    , assertEqual "absoluteThenNegate 0" (absoluteThenNegate 0) 0
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
