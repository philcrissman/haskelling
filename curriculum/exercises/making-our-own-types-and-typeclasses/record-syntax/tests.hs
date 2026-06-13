module Main where

import System.Exit (exitFailure, exitSuccess)
import RecordSyntax

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
  let ada = Person { name = "Ada", age = 36 }
  results <- sequence
    [ assertEqual "age increments" (age (birthday ada)) 37
    , assertEqual "name unchanged" (name (birthday ada)) "Ada"
    , assertEqual "whole record" (birthday ada) (Person { name = "Ada", age = 37 })
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
