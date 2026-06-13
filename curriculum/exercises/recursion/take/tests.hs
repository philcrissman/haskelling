module Main where

import System.Exit (exitFailure, exitSuccess)
import Take

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
    [ assertEqual "takes the first two" (take' 2 [1, 2, 3, 4 :: Int]) [1, 2]
    , assertEqual "takes zero" (take' 0 [1, 2 :: Int]) []
    , assertEqual "takes more than available" (take' 5 [1, 2 :: Int]) [1, 2]
    , assertEqual "takes from a string" (take' 3 "haskell") "has"
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
