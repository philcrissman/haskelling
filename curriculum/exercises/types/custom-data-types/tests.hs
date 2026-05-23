module Main where

import System.Exit (exitFailure, exitSuccess)
import CustomDataTypes

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
    [ assertEqual "North is opposite of South" (opposite North) (South)
    , assertEqual "South is opposite of North" (opposite South) (North)
    , assertEqual "East is opposite of West" (opposite East) (West)
    , assertEqual "West is opposite of East" (opposite West) (East)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
