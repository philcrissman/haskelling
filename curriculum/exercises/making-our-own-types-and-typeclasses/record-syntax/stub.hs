module RecordSyntax where

data Person = Person { name :: String, age :: Int }
  deriving (Show, Eq)

birthday :: Person -> Person
birthday p = undefined
