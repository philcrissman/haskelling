module CustomDataTypes where

data Direction = North | South | East | West deriving (Eq, Show)

-- Return the opposite direction.
opposite :: Direction -> Direction
opposite dir = undefined