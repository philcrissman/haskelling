module CaseExpressions where

describe :: Int -> String
describe n = case compare n 0 of
  LT -> "negative"
  EQ -> "zero"
  GT -> "positive"