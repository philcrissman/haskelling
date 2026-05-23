module FunctionComposition where

absoluteThenNegate :: Int -> Int
absoluteThenNegate = negate . abs