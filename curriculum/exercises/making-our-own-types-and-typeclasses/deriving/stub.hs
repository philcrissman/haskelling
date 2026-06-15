module Deriving where

-- Add a deriving clause to Priority so the tests below can compare, show,
-- and enumerate its values (they use Eq, Ord, Show, Enum, and Bounded).
data Priority = Low | Medium | High

-- isUrgent returns True only for High, and False otherwise.
isUrgent :: Priority -> Bool
isUrgent p = undefined
