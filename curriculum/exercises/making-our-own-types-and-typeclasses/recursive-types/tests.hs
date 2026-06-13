module Main where

import System.Exit (exitFailure, exitSuccess)
import RecursiveTypes

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
  let tree = Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)
  results <- sequence
    [ assertEqual "sums a small tree" (treeSum tree) 6
    , assertEqual "empty tree is 0" (treeSum Leaf) 0
    , assertEqual "single node" (treeSum (Node Leaf 5 Leaf)) 5
    ]
  let passed = length (filter id results)
      failed  = length results - passed
  putStrLn $ show (length results) ++ " examples, " ++ show failed ++ " failures"
  if failed == 0 then exitSuccess else exitFailure
