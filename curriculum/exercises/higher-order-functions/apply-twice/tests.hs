module Main where

import System.Exit (exitFailure, exitSuccess)
import ApplyTwice

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
    [ assertEqual "adds three twice" (applyTwice (+ 3) (10 :: Int)) 16
    , assertEqual "appends twice" (applyTwice (++ " ha") "hey") "hey ha ha"
    , assertEqual "conses twice" (applyTwice (3 :) [1 :: Int]) [3, 3, 1]
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
