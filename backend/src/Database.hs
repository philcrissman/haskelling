module Database where

import Control.Monad.Logger (runStdoutLoggingT)
import Data.ByteString (ByteString)
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)

makePool :: ByteString -> Int -> IO ConnectionPool
makePool connStr poolSize =
  runStdoutLoggingT $ createPostgresqlPool connStr poolSize
