module Main where

import System.Exit (exitFailure, exitSuccess)
import ListConstruction

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
    [ assertEqual "prepends to a non-empty list" (prepend 1 [2,3,4]) ([1,2,3,4])
    , assertEqual "prepends to an empty list" (prepend 5 []) ([5])
    , assertEqual "prepends 0 to a list" (prepend 0 [1,2,3]) ([0,1,2,3])
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
