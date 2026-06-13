module TypeParameters where

data Optional a = None | Some a
  deriving (Show, Eq)

withDefault :: a -> Optional a -> a
withDefault _   (Some x) = x
withDefault def None     = def
