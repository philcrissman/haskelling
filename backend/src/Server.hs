{-# LANGUAGE DataKinds #-}

module Server
  ( app
  , newRateLimiter
  , RateLimiter
  ) where

import API
import Auth (AuthEnv)
import Auth qualified
import Control.Concurrent.STM
import Control.Monad (forM)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Char8 qualified as BC8
import Data.List (sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes)
import Data.Ord (comparing)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime, diffUTCTime, getCurrentTime)
import Database.Persist (Entity (..), SelectOpt (..), get, getBy, insert, insert_, selectList, update, (==.), (=.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Database.Persist.Sql (SqlPersistT, fromSqlKey)
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

-- Auth helper: extract Bearer token, validate, look up or create user

requireUser :: AuthEnv -> ConnectionPool -> Maybe Text -> Handler Schema.UserId
requireUser authEnv pool mAuthHeader = do
  token <- case mAuthHeader >>= T.stripPrefix "Bearer " of
    Nothing -> jsonError err401 "authentication required" "unauthenticated"
    Just t  -> pure t
  clerkId <- liftIO (Auth.validateToken authEnv token) >>= \case
    Left _  -> jsonError err401 "invalid or expired token" "unauthenticated"
    Right c -> pure c
  upsertClerkUser authEnv pool clerkId

upsertClerkUser :: AuthEnv -> ConnectionPool -> Text -> Handler Schema.UserId
upsertClerkUser authEnv pool clerkId = do
  mExisting <- liftIO $ runSqlPool (getBy (Schema.UniqueClerkId clerkId)) pool
  case mExisting of
    Just (Entity k _) -> pure k
    Nothing -> do
      info <- liftIO $ Auth.fetchClerkUser authEnv clerkId
      now  <- liftIO getCurrentTime
      let (username, email, avatar) = case info of
            Right u -> ( Auth.clerkUserUsername u
                       , Auth.clerkUserEmail u
                       , Auth.clerkUserAvatar u )
            Left  _ -> (clerkId, Nothing, Nothing)
      liftIO $ runSqlPool (insert Schema.User
        { Schema.userClerkId   = clerkId
        , Schema.userUsername  = username
        , Schema.userEmail     = email
        , Schema.userAvatarUrl = avatar
        , Schema.userCreatedAt = now
        , Schema.userUpdatedAt = now
        }) pool

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

submitHandler :: Judge0Config -> ConnectionPool -> AuthEnv -> Maybe Text -> SubmitRequest -> Handler SubmitResponse
submitHandler cfg pool authEnv mAuth req = do
  userId <- requireUser authEnv pool mAuth
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
        { Schema.submissionUserId      = Just userId
        , Schema.submissionExerciseId  = exerciseKey
        , Schema.submissionCode        = code
        , Schema.submissionStatus      = srStatus result
        , Schema.submissionOutput      = srOutput result
        , Schema.submissionPassedCount = srPassedCount result
        , Schema.submissionFailedCount = srFailedCount result
        , Schema.submissionCreatedAt   = now
        }) pool
      liftIO $ runSqlPool (upsertProgress userId exerciseKey (srStatus result) now) pool
      pure SubmitResponse
        { submitStatus      = statusToText (srStatus result)
        , submitOutput      = srOutput result
        , submitPassedCount = srPassedCount result
        , submitFailedCount = srFailedCount result
        }

submissionHistoryHandler :: ConnectionPool -> AuthEnv -> Text -> Maybe Text -> Handler SubmissionHistoryResponse
submissionHistoryHandler pool authEnv eid mAuth = do
  userId <- requireUser authEnv pool mAuth
  mEx <- liftIO $ runSqlPool (getBy (Schema.UniqueExerciseSlug eid)) pool
  exerciseKey <- case mEx of
    Nothing           -> jsonError err404 "exercise not found" "not_found"
    Just (Entity k _) -> pure k
  subs <- liftIO $ runSqlPool
    (selectList
      [ Schema.SubmissionExerciseId ==. exerciseKey
      , Schema.SubmissionUserId     ==. Just userId
      ]
      [Desc Schema.SubmissionCreatedAt])
    pool
  pure $ SubmissionHistoryResponse { historySubmissions = map toHistoryItem subs }
  where
    toHistoryItem (Entity key sub) = SubmissionHistoryItem
      { histId          = fromSqlKey key
      , histStatus      = statusToText (Schema.submissionStatus sub)
      , histOutput      = Schema.submissionOutput sub
      , histPassedCount = Schema.submissionPassedCount sub
      , histFailedCount = Schema.submissionFailedCount sub
      , histCreatedAt   = Schema.submissionCreatedAt sub
      }

progressHandler :: AuthEnv -> ConnectionPool -> Maybe Text -> Handler ProgressResponse
progressHandler authEnv pool mAuth = do
  userId    <- requireUser authEnv pool mAuth
  progresses <- liftIO $ runSqlPool
    (selectList [Schema.UserProgressUserId ==. userId] [])
    pool
  items <- liftIO $ forM progresses $ \(Entity _ up) -> do
    mEx <- runSqlPool (get (Schema.userProgressExerciseId up)) pool
    pure $ case mEx of
      Nothing -> Nothing
      Just ex -> Just ProgressItem
        { progressExerciseId    = Schema.exerciseSlug ex
        , progressStatus        = progressStatusToText (Schema.userProgressStatus up)
        , progressFirstPassedAt = Schema.userProgressFirstPassedAt up
        , progressLastSubmitted = Schema.userProgressLastSubmittedAt up
        }
  pure $ ProgressResponse { progressItems = catMaybes items }

-- Upsert user progress after a submission

upsertProgress :: Schema.UserId -> Schema.ExerciseId -> Schema.SubmissionStatus -> UTCTime -> SqlPersistT IO ()
upsertProgress userId exId subStatus now = do
  let newProgStatus = case subStatus of
        Schema.StatusPass -> Schema.Passed
        _                 -> Schema.Attempted
  mExisting <- getBy (Schema.UniqueUserExercise userId exId)
  case mExisting of
    Nothing ->
      insert_ Schema.UserProgress
        { Schema.userProgressUserId          = userId
        , Schema.userProgressExerciseId      = exId
        , Schema.userProgressStatus          = newProgStatus
        , Schema.userProgressFirstPassedAt   = if subStatus == Schema.StatusPass then Just now else Nothing
        , Schema.userProgressLastSubmittedAt = now
        }
    Just (Entity k up) -> do
      let alreadyPassed = Schema.userProgressStatus up == Schema.Passed
          finalStatus   = if alreadyPassed then Schema.Passed else newProgStatus
          firstPassed   = case Schema.userProgressFirstPassedAt up of
            Just t  -> Just t
            Nothing -> if subStatus == Schema.StatusPass then Just now else Nothing
      update k
        [ Schema.UserProgressStatus          =. finalStatus
        , Schema.UserProgressFirstPassedAt   =. firstPassed
        , Schema.UserProgressLastSubmittedAt =. now
        ]

progressStatusToText :: Schema.ProgressStatus -> Text
progressStatusToText Schema.NotStarted = "not_started"
progressStatusToText Schema.Attempted  = "attempted"
progressStatusToText Schema.Passed     = "passed"

-- App

server :: Judge0Config -> ConnectionPool -> AuthEnv -> Server API
server cfg pool authEnv =
  healthHandler
    :<|> (exercisesListHandler pool :<|> exerciseByIdHandler pool)
    :<|> submitHandler cfg pool authEnv
    :<|> submissionHistoryHandler pool authEnv
    :<|> progressHandler authEnv pool

app :: Judge0Config -> RateLimiter -> Int -> ConnectionPool -> AuthEnv -> Application
app cfg limiter rateLimit pool authEnv =
  loggingMiddleware $
  rateLimitMiddleware limiter rateLimit $
  serve (Proxy :: Proxy API) (server cfg pool authEnv)

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
