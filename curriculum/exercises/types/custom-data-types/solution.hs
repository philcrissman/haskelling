module CustomDataTypes where

data Direction = North | South | East | West deriving (Eq, Show)

opposite :: Direction -> Direction
opposite North = South
opposite South = North
opposite East  = West
opposite West  = East