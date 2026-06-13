module Main where

import System.Exit (exitFailure, exitSuccess)
import TypeVariables

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
    [ assertEqual "swaps an Int/Char pair" (swapPair (1 :: Int, 'a')) ('a', 1)
    , assertEqual "swaps a Bool/String pair" (swapPair (True, "hi")) ("hi", True)
    , assertEqual "swaps two ints" (swapPair (3 :: Int, 4 :: Int)) (4, 3)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
