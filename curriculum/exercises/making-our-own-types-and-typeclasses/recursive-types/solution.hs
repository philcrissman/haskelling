module RecursiveTypes where

data Tree a = Leaf | Node (Tree a) a (Tree a)
  deriving (Show, Eq)

treeSum :: Tree Int -> Int
treeSum Leaf         = 0
treeSum (Node l x r) = treeSum l + x + treeSum r
