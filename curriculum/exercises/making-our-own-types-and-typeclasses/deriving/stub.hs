module Deriving where

-- Add a deriving clause to Priority so the tests below can compare, show,
-- and enumerate its values.
data Priority = Low | Medium | High

isUrgent :: Priority -> Bool
isUrgent p = undefined
