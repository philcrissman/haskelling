module Main where

import System.Exit (exitFailure, exitSuccess)
import FmapMaybe

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
    [ assertEqual "doubles Just 5 to Just 10" (doubleIfPresent (Just 5)) (Just 10)
    , assertEqual "returns Nothing for Nothing" (doubleIfPresent Nothing) (Nothing)
    , assertEqual "doubles Just 0 to Just 0" (doubleIfPresent (Just 0)) (Just 0)
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
