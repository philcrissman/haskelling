module ImplementingEq where

data Point = Point Int Int

instance Eq Point where
  (==) (Point x1 y1) (Point x2 y2) = x1 == x2 && y1 == y2