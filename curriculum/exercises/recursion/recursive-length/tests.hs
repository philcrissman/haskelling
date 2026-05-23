module Main where

import System.Exit (exitFailure, exitSuccess)
import RecursiveLength

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
    [ assertEqual "empty list has length 0" (myLength ([] :: [Int])) (0)
    , assertEqual "[1,2,3] has length 3" (myLength [1 :: Int, 2, 3]) (3)
    , assertEqual "works on a list of strings" (myLength ["a", "b", "c", "d"]) (4)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
