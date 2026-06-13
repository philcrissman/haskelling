module Main where

import System.Exit (exitFailure, exitSuccess)
import TypeSynonyms

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
  let book = [("alice", "123"), ("bob", "456")]
  results <- sequence
    [ assertEqual "finds an entry" (lookupNumber "bob" book) (Just "456")
    , assertEqual "missing entry is Nothing" (lookupNumber "carol" book) Nothing
    , assertEqual "finds the first" (lookupNumber "alice" book) (Just "123")
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
