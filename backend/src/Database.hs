module Database where

import Control.Monad (forM_)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import Database.Persist.Sql (SqlPersistT, rawExecute)

makePool :: ByteString -> Int -> IO ConnectionPool
makePool connStr poolSize =
  runStdoutLoggingT $ createPostgresqlPool connStr poolSize

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
