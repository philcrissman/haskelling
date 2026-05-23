module Main where

import System.Exit (exitFailure, exitSuccess)
import DerivingEq

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
    [ assertEqual "Clubs equals Clubs" (sameSuit Clubs Clubs) (True)
    , assertEqual "Clubs does not equal Hearts" (sameSuit Clubs Hearts) (False)
    , assertEqual "Spades equals Spades" (sameSuit Spades Spades) (True)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
