module Main where

import System.Exit (exitFailure, exitSuccess)
import BooleanValues

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
    [ assertEqual "returns True for age 18" (isAdult 18) (True)
    , assertEqual "returns True for age 21" (isAdult 21) (True)
    , assertEqual "returns False for age 17" (isAdult 17) (False)
    , assertEqual "returns False for age 0" (isAdult 0) (False)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
