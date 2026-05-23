module PatternMatchingLists where

isSingleton :: [a] -> Bool
isSingleton [_] = True
isSingleton _   = False