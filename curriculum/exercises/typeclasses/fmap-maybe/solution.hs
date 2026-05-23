module FmapMaybe where

doubleIfPresent :: Maybe Int -> Maybe Int
doubleIfPresent m = fmap (*2) m