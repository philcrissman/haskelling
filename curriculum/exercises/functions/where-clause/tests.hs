module Main where

import System.Exit (exitFailure, exitSuccess)
import WhereClause

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
    [ assertEqual "hypotenuse 3 4" (hypotenuse 3 4) 5.0
    , assertEqual "hypotenuse 5 12" (hypotenuse 5 12) 13.0
    , assertEqual "hypotenuse 0 0" (hypotenuse 0 0) 0.0
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
