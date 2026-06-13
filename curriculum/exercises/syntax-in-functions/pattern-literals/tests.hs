module Main where

import System.Exit (exitFailure, exitSuccess)
import PatternLiterals

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
    [ assertEqual "matches 1" (sayMe 1) "one"
    , assertEqual "matches 2" (sayMe 2) "two"
    , assertEqual "matches 3" (sayMe 3) "three"
    , assertEqual "catch-all for others" (sayMe 7) "many"
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
