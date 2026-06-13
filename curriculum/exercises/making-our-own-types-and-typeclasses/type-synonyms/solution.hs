module TypeSynonyms where

type PhoneBook = [(String, String)]

lookupNumber :: String -> PhoneBook -> Maybe String
lookupNumber name book = lookup name book
