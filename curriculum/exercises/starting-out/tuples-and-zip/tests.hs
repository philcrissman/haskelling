module Main where

import System.Exit (exitFailure, exitSuccess)
import TuplesAndZip

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
    [ assertEqual "pairs numbers with letters" (pairUp [1, 2, 3 :: Int] "abc") [(1, 'a'), (2, 'b'), (3, 'c')]
    , assertEqual "stops at the shorter list" (pairUp [1, 2, 3, 4 :: Int] [True, False]) [(1, True), (2, False)]
    , assertEqual "empty when one list is empty" (pairUp ([] :: [Int]) "x") []
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
