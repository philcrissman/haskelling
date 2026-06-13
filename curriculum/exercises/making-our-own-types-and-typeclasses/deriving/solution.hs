module Deriving where

data Priority = Low | Medium | High
  deriving (Eq, Ord, Show, Enum, Bounded)

isUrgent :: Priority -> Bool
isUrgent p = p == High
