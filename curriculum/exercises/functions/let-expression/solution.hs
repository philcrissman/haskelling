module LetExpression where

doubledArea :: Int -> Int -> Int
doubledArea w h =
  let area = w * h
  in  area * 2