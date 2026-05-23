module Main where

import System.Exit (exitFailure, exitSuccess)
import PartialApplication

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
    [ assertEqual "addFive 3" (addFive 3) 8
    , assertEqual "addFive 0" (addFive 0) 5
    , assertEqual "multiplyByThree 4" (multiplyByThree 4) 12
    , assertEqual "multiplyByThree 0" (multiplyByThree 0) 0
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
