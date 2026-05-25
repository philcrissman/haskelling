module Main where

import Auth (newAuthEnv, parseJwksUrl)
import Control.Monad (when)
import Data.ByteString.Char8 qualified as BC8
import Data.Text qualified as T
import Database (createIndexes, makePool)
import Database.Persist.Postgresql (runSqlPool)
import Database.Persist.Sql (runMigration)
import Judge0 (Judge0Config (..))
import Network.Wai.Handler.Warp (run)
import Schema (migrateAll)
import Seed (seedFromDir)
import Server (app, newRateLimiter)
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
  runSqlPool createIndexes pool
  putStrLn "haskelling: migrations and indexes applied"

  -- Seed
  curriculumDir <- lookupEnv "CURRICULUM_DIR" >>= \case
    Just p  -> pure p
    Nothing -> pure "../curriculum"
  seedFromDir curriculumDir pool

  -- Judge0
  judge0Cfg <- do
    apiUrl  <- lookupEnv "JUDGE0_API_URL"  >>= \case
      Just u  -> pure (T.pack u)
      Nothing -> pure "https://judge0-ce.p.rapidapi.com"
    apiKey  <- lookupEnv "JUDGE0_API_KEY"  >>= \case
      Just k  -> pure (T.pack k)
      Nothing -> pure ""
    apiHost <- lookupEnv "JUDGE0_API_HOST" >>= \case
      Just h  -> pure (T.pack h)
      Nothing -> pure "judge0-ce.p.rapidapi.com"
    mockStr <- lookupEnv "JUDGE0_MOCK"
    let isMock = mockStr == Just "true"
    when isMock $ putStrLn "haskelling: Judge0 mock mode enabled"
    pure Judge0Config
      { judge0ApiUrl  = apiUrl
      , judge0ApiKey  = apiKey
      , judge0ApiHost = apiHost
      , judge0Mock    = isMock
      }

  -- Clerk auth
  authEnv <- do
    pk <- lookupEnv "CLERK_PUBLISHABLE_KEY" >>= \case
      Nothing -> die "CLERK_PUBLISHABLE_KEY is not set"
      Just k  -> pure (T.pack k)
    sk <- lookupEnv "CLERK_SECRET_KEY" >>= \case
      Nothing -> die "CLERK_SECRET_KEY is not set"
      Just k  -> pure (T.pack k)
    jwksUrl <- case parseJwksUrl pk of
      Left err  -> die ("Failed to derive JWKS URL: " <> T.unpack err)
      Right url -> pure url
    putStrLn $ "haskelling: Clerk JWKS URL: " <> T.unpack jwksUrl
    newAuthEnv jwksUrl sk

  -- Draft content
  showDraft <- do
    s <- lookupEnv "SHOW_DRAFT_CONTENT"
    pure $ s == Just "true"
  when showDraft $ putStrLn "haskelling: draft content visible"

  -- Rate limiting
  rateLimitPerIp <- do
    s <- lookupEnv "RATE_LIMIT_PER_IP"
    pure $ case s >>= readMaybe of
      Just n  -> n
      Nothing -> 20
  rateLimitPerUser <- do
    s <- lookupEnv "RATE_LIMIT_PER_USER"
    pure $ case s >>= readMaybe of
      Just n  -> n
      Nothing -> 10
  ipLimiter   <- newRateLimiter
  userLimiter <- newRateLimiter

  -- Serve
  putStrLn $ "haskelling: listening on port " <> show port
  run port (app showDraft judge0Cfg ipLimiter rateLimitPerIp userLimiter rateLimitPerUser pool authEnv)
