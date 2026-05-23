module PatternMatchingMaybe where

incrementMaybe :: Maybe Int -> Maybe Int
incrementMaybe Nothing  = Nothing
incrementMaybe (Just n) = Just (n + 1)