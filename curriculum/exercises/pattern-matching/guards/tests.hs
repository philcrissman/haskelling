module Main where

import System.Exit (exitFailure, exitSuccess)
import Guards

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
    [ assertEqual "returns A for 95" (letterGrade 95) ("A")
    , assertEqual "returns B for 85" (letterGrade 85) ("B")
    , assertEqual "returns C for 75" (letterGrade 75) ("C")
    , assertEqual "returns D for 65" (letterGrade 65) ("D")
    , assertEqual "returns F for 55" (letterGrade 55) ("F")
    , assertEqual "returns A for 90" (letterGrade 90) ("A")
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
