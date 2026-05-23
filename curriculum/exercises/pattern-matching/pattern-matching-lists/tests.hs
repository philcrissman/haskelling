module Main where

import System.Exit (exitFailure, exitSuccess)
import PatternMatchingLists

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
    [ assertEqual "returns True for a one-element list" (isSingleton [42 :: Int]) (True)
    , assertEqual "returns False for an empty list" (isSingleton ([] :: [Int])) (False)
    , assertEqual "returns False for a two-element list" (isSingleton [1 :: Int, 2]) (False)
    , assertEqual "returns False for a longer list" (isSingleton [1 :: Int, 2, 3]) (False)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
