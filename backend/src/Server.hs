{-# LANGUAGE DataKinds #-}

module Server
  ( app
  , newRateLimiter
  , RateLimiter
  ) where

import API
import Control.Concurrent.STM
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Char8 qualified as BC8
import Data.List (sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (comparing)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime, diffUTCTime, getCurrentTime)
import Database.Persist (Entity (..), SelectOpt (..), get, getBy, insert_, selectList, (==.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Database.Persist.Sql (fromSqlKey)
import Judge0 (Judge0Config (..), SubmissionResult (..), submitAndWait)
import Network.HTTP.Types (statusCode, status429)
import Network.Socket (SockAddr (..), hostAddressToTuple)
import Network.Wai (pathInfo, remoteHost, requestMethod, responseStatus, responseLBS)
import qualified Schema
import Schema (HintList (..))
import Servant

-- Rate limiter: per-IP sliding window (count, window-start)

type RateLimiter = TVar (Map Text (Int, UTCTime))

newRateLimiter :: IO RateLimiter
newRateLimiter = newTVarIO Map.empty

checkAndIncrement :: RateLimiter -> Int -> Text -> UTCTime -> STM Bool
checkAndIncrement limiter maxPerMin ip now = do
  m <- readTVar limiter
  let (count, windowStart) = maybe (0, now) id (Map.lookup ip m)
      elapsed              = diffUTCTime now windowStart
  if elapsed >= 60
    then writeTVar limiter (Map.insert ip (1, now) m)      >> pure True
    else if count >= maxPerMin
           then pure False
           else writeTVar limiter (Map.insert ip (count + 1, windowStart) m) >> pure True

sockAddrIp :: SockAddr -> Text
sockAddrIp (SockAddrInet _ addr) =
  let (a, b, c, d) = hostAddressToTuple addr
  in T.intercalate "." (map (T.pack . show) [a, b, c, d])
sockAddrIp sa = T.pack (show sa)

-- Error helper

jsonError :: ServerError -> Text -> Text -> Handler a
jsonError base msg code =
  throwError
    base
      { errBody    = encode (object ["error" .= msg, "code" .= code])
      , errHeaders = [("Content-Type", "application/json")]
      }

-- DB → API conversion helpers

toExerciseClient :: Text -> Entity Schema.Exercise -> ExerciseClient
toExerciseClient chapSlug (Entity _ ex) = ExerciseClient
  { exerciseId          = Schema.exerciseSlug ex
  , exerciseTitle       = Schema.exerciseTitle ex
  , exerciseChapter     = chapSlug
  , exerciseOrder       = Schema.exerciseOrderInChapter ex
  , exerciseLearningObj = Schema.exerciseLearningObjective ex
  , exerciseStubCode    = Schema.exerciseStubCode ex
  , exerciseHints       = getHints (Schema.exerciseHints ex)
  }

toChapterResponse :: Entity Schema.Chapter -> [Entity Schema.Exercise] -> ChapterResponse
toChapterResponse (Entity _ ch) exs = ChapterResponse
  { chapterSlug        = Schema.chapterSlug ch
  , chapterTitle       = Schema.chapterTitle ch
  , chapterDescription = Schema.chapterDescription ch
  , chapterLesson      = Schema.chapterLesson ch
  , chapterExercises   = map (toExerciseClient (Schema.chapterSlug ch)) exs
  }

-- Handlers

healthHandler :: Handler HealthResponse
healthHandler = return $ HealthResponse { status = "ok" }

exercisesListHandler :: ConnectionPool -> Handler ExercisesListResponse
exercisesListHandler pool = do
  chapters  <- liftIO $ runSqlPool (selectList [] [Asc Schema.ChapterOrderNum]) pool
  exercises <- liftIO $ runSqlPool (selectList [] [Asc Schema.ExerciseOrderInChapter]) pool
  let byChapter = Map.fromListWith (flip (++))
        [ (Schema.exerciseChapterId (entityVal e), [e]) | e <- exercises ]
      chapterResps = map (\c ->
        let key = entityKey c
            exs = sortBy (comparing (Schema.exerciseOrderInChapter . entityVal))
                    (Map.findWithDefault [] key byChapter)
        in toChapterResponse c exs
        ) chapters
  return $ ExercisesListResponse { responseChapters = chapterResps }

exerciseByIdHandler :: ConnectionPool -> Text -> Handler ExerciseClient
exerciseByIdHandler pool eid = do
  mEx <- liftIO $ runSqlPool (getBy (Schema.UniqueExerciseSlug eid)) pool
  case mEx of
    Nothing -> jsonError err404 "exercise not found" "not_found"
    Just ex@(Entity _ exVal) -> do
      mCh <- liftIO $ runSqlPool (get (Schema.exerciseChapterId exVal)) pool
      case mCh of
        Nothing -> jsonError err500 "chapter not found" "internal_error"
        Just ch -> pure $ toExerciseClient (Schema.chapterSlug ch) ex

submitHandler :: Judge0Config -> ConnectionPool -> SubmitRequest -> Handler SubmitResponse
submitHandler cfg pool req = do
  let eid  = submitExerciseId req
      code = submitCode req
  if T.length code > 50_000
    then jsonError err413 "code exceeds 50KB limit" "too_large"
    else do
      mEx <- liftIO $ runSqlPool (getBy (Schema.UniqueExerciseSlug eid)) pool
      (exerciseKey, hiddenTests) <- case mEx of
        Nothing       -> jsonError err404 "exercise not found" "not_found"
        Just (Entity key exVal) -> pure (key, Schema.exerciseHiddenTests exVal)
      result <- liftIO $ submitAndWait cfg eid code hiddenTests
      now    <- liftIO getCurrentTime
      liftIO $ runSqlPool (insert_ Schema.Submission
        { Schema.submissionUserId      = Nothing
        , Schema.submissionExerciseId  = exerciseKey
        , Schema.submissionCode        = code
        , Schema.submissionStatus      = srStatus result
        , Schema.submissionOutput      = srOutput result
        , Schema.submissionPassedCount = srPassedCount result
        , Schema.submissionFailedCount = srFailedCount result
        , Schema.submissionCreatedAt   = now
        }) pool
      pure SubmitResponse
        { submitStatus      = statusToText (srStatus result)
        , submitOutput      = srOutput result
        , submitPassedCount = srPassedCount result
        , submitFailedCount = srFailedCount result
        }

submissionHistoryHandler :: ConnectionPool -> Text -> Handler SubmissionHistoryResponse
submissionHistoryHandler pool eid = do
  mEx <- liftIO $ runSqlPool (getBy (Schema.UniqueExerciseSlug eid)) pool
  exerciseKey <- case mEx of
    Nothing          -> jsonError err404 "exercise not found" "not_found"
    Just (Entity k _) -> pure k
  subs <- liftIO $ runSqlPool
    (selectList [Schema.SubmissionExerciseId ==. exerciseKey] [Desc Schema.SubmissionCreatedAt])
    pool
  let items = map toHistoryItem subs
  pure $ SubmissionHistoryResponse { historySubmissions = items }
  where
    toHistoryItem (Entity key sub) = SubmissionHistoryItem
      { histId          = fromSqlKey key
      , histStatus      = statusToText (Schema.submissionStatus sub)
      , histOutput      = Schema.submissionOutput sub
      , histPassedCount = Schema.submissionPassedCount sub
      , histFailedCount = Schema.submissionFailedCount sub
      , histCreatedAt   = Schema.submissionCreatedAt sub
      }

progressHandler :: Handler ProgressResponse
progressHandler = pure $ ProgressResponse { progressItems = [] }

-- App

server :: Judge0Config -> ConnectionPool -> Server API
server cfg pool =
  healthHandler
    :<|> (exercisesListHandler pool :<|> exerciseByIdHandler pool)
    :<|> submitHandler cfg pool
    :<|> submissionHistoryHandler pool
    :<|> progressHandler

app :: Judge0Config -> RateLimiter -> Int -> ConnectionPool -> Application
app cfg limiter rateLimit pool =
  loggingMiddleware $
  rateLimitMiddleware limiter rateLimit $
  serve (Proxy :: Proxy API) (server cfg pool)

-- Middleware

rateLimitMiddleware :: RateLimiter -> Int -> Application -> Application
rateLimitMiddleware limiter maxPerMin inner req send =
  if requestMethod req == "POST" && pathInfo req == ["api", "submissions"]
    then do
      now <- getCurrentTime
      let ip = sockAddrIp (remoteHost req)
      allowed <- atomically $ checkAndIncrement limiter maxPerMin ip now
      if allowed
        then inner req send
        else send $ responseLBS status429
               [ ("Content-Type", "application/json")
               , ("Retry-After",  "60")
               ]
               (encode (object ["error" .= ("rate limit exceeded" :: Text), "code" .= ("rate_limited" :: Text)]))
    else inner req send

loggingMiddleware :: Application -> Application
loggingMiddleware inner req send =
  inner req $ \resp -> do
    let sc     = statusCode (responseStatus resp)
        method = BC8.unpack (requestMethod req)
        path   = "/" <> T.unpack (T.intercalate "/" (pathInfo req))
    putStrLn $ method <> " " <> path <> " " <> show sc
    send resp
