module Main where

import System.Exit (exitFailure, exitSuccess)
import TypeSignatures

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
    [ assertEqual "joins two words" (joinWithSpace "hello" "world") ("hello world")
    , assertEqual "joins with a space in between" (joinWithSpace "foo" "bar") ("foo bar")
    , assertEqual "joins with empty string" (joinWithSpace "" "bar") (" bar")
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
