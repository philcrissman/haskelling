module CaseExpression where

describeList :: [a] -> String
describeList xs = "The list is " ++ case xs of
  []  -> "empty."
  [_] -> "a singleton list."
  _   -> "a longer list."
