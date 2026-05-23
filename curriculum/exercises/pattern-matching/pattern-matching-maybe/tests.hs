module Main where

import System.Exit (exitFailure, exitSuccess)
import PatternMatchingMaybe

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
    [ assertEqual "increments Just 5 to Just 6" (incrementMaybe (Just 5)) (Just 6)
    , assertEqual "returns Nothing for Nothing" (incrementMaybe Nothing) (Nothing)
    , assertEqual "increments Just 0 to Just 1" (incrementMaybe (Just 0)) (Just 1)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
