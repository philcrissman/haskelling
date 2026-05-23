module Main where

import System.Exit (exitFailure, exitSuccess)
import ListBasics

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
    [ assertEqual "returns 2 from [1,2,3]" (secondElement [1,2,3]) (2)
    , assertEqual "returns 20 from [10,20,30]" (secondElement [10,20,30]) (20)
    , assertEqual "returns the second of a two-element list" (secondElement [7,8]) (8)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
