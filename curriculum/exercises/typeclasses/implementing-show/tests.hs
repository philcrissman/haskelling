module Main where

import System.Exit (exitFailure, exitSuccess)
import ImplementingShow

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
    [ assertEqual "shows Clubs as the club symbol" (show Clubs) ("\9827")
    , assertEqual "shows Diamonds as the diamond symbol" (show Diamonds) ("\9830")
    , assertEqual "shows Hearts as the heart symbol" (show Hearts) ("\9829")
    , assertEqual "shows Spades as the spade symbol" (show Spades) ("\9824")
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
