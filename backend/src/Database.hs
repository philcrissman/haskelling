module Database where

import Control.Monad (forM_)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Database.Persist.Postgresql
  ( ConnectionPool
  , PostgresConf (..)
  , createPostgresqlPoolWithConf
  , defaultPostgresConfHooks
  )
import Database.Persist.Sql (SqlPersistT, rawExecute)

-- | Build the connection pool. We set a short idle timeout so idle connections
-- are recycled before Neon's autosuspend (~5 min) drops them server-side —
-- otherwise the first request after the compute scales to zero could be handed
-- a stale connection from the pool.
makePool :: ByteString -> Int -> IO ConnectionPool
makePool connStr poolSize =
  runStdoutLoggingT $ createPostgresqlPoolWithConf conf defaultPostgresConfHooks
  where
    conf = PostgresConf
      { pgConnStr         = connStr
      , pgPoolSize        = poolSize
      , pgPoolStripes     = 1
      , pgPoolIdleTimeout = 120  -- seconds
      }

-- Create non-unique indexes that Persistent's migrateAll does not manage.
-- All statements are idempotent (IF NOT EXISTS).
createIndexes :: SqlPersistT IO ()
createIndexes = forM_ statements $ \sql -> rawExecute sql []
  where
    statements :: [Text]
    statements =
      [ "CREATE INDEX IF NOT EXISTS idx_exercise_chapter_order \
        \ON exercise(chapter_id, order_in_chapter)"
      , "CREATE INDEX IF NOT EXISTS idx_chapter_order \
        \ON chapter(order_num)"
      , "CREATE INDEX IF NOT EXISTS idx_submission_user_exercise \
        \ON submission(user_id, exercise_id)"
      , "CREATE INDEX IF NOT EXISTS idx_submission_user_created \
        \ON submission(user_id, created_at DESC)"
      , "CREATE INDEX IF NOT EXISTS idx_user_progress_user \
        \ON user_progress(user_id)"
      ]
