module Main where

import System.Exit (exitFailure, exitSuccess)
import TailRecursion

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
    [ assertEqual "reverses an empty list" (myReverse ([] :: [Int])) ([])
    , assertEqual "reverses [1,2,3]" (myReverse [1 :: Int, 2, 3]) ([3, 2, 1])
    , assertEqual "reverses a long list" (myReverse [1..100 :: Int]) ([100,99..1])
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
