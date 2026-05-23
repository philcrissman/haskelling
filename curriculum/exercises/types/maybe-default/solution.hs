module MaybeDefault where

import Data.Maybe (fromMaybe)

orZero :: Maybe Int -> Int
orZero m = fromMaybe 0 m