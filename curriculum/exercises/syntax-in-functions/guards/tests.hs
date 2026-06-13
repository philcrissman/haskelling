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
    [ assertEqual "90+ is an A" (gradeLetter 95) 'A'
    , assertEqual "80s is a B" (gradeLetter 85) 'B'
    , assertEqual "70s is a C" (gradeLetter 72) 'C'
    , assertEqual "below 70 is an F" (gradeLetter 50) 'F'
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
