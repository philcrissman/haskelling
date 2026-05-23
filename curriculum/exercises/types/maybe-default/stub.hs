module MaybeDefault where

import Data.Maybe (fromMaybe)

-- Return the Int inside the Maybe, or 0 if it is Nothing.
orZero :: Maybe Int -> Int
orZero m = undefined