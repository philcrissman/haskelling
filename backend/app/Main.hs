module Main where

import Data.ByteString.Char8 qualified as BC8
import Database (makePool)
import Database.Persist.Postgresql (runSqlPool)
import Database.Persist.Sql (runMigration)
import Network.Wai.Handler.Warp (run)
import Schema (migrateAll)
import Seed (seedFromFile)
import Server (app)
import System.Environment (lookupEnv)
import System.Exit (die)
import Text.Read (readMaybe)

main :: IO ()
main = do
  -- Port
  portStr <- lookupEnv "PORT"
  let port = case portStr >>= readMaybe of
        Just p -> p
        Nothing -> 8080

  -- Database
  dbUrl <- lookupEnv "DATABASE_URL" >>= \case
    Nothing -> die "DATABASE_URL is not set"
    Just url -> pure (BC8.pack url)
  poolSizeStr <- lookupEnv "DB_POOL_SIZE"
  let poolSize = case poolSizeStr >>= readMaybe of
        Just n -> n
        Nothing -> 10

  pool <- makePool dbUrl poolSize
  runSqlPool (runMigration migrateAll) pool
  putStrLn "haskelling: migrations applied"

  -- Seed
  curriculumPath <- lookupEnv "CURRICULUM_PATH" >>= \case
    Just p -> pure p
    Nothing -> pure "../CURRICULUM.json"
  seedFromFile curriculumPath pool

  -- Serve
  putStrLn $ "haskelling: listening on port " <> show port
  run port app
