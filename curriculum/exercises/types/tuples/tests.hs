module Main where

import System.Exit (exitFailure, exitSuccess)
import Tuples

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
    [ assertEqual "swaps an Int and a String" (swap (1 :: Int, "hello")) (("hello", 1))
    , assertEqual "swaps two Strings" (swap ("a", "b")) (("b", "a"))
    , assertEqual "swaps identical types" (swap (True, False)) ((False, True))
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
