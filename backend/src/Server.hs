{-# LANGUAGE DataKinds #-}

module Server
  ( app
  , newRateLimiter
  , RateLimiter
  ) where

import API
import Auth (AuthEnv)
import Auth qualified
import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM
import Control.Exception (SomeException, try)
import Control.Monad (forever, void, when)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Char8 qualified as BC8
import Data.List (sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (comparing)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Time (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import Database.Persist (Entity (..), SelectOpt (..), get, getBy, insert, insert_, selectList, update, (==.), (!=.), (=.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Database.Persist.Sql (SqlPersistT, Single (..), fromSqlKey, rawSql)
import Judge0 (Judge0Config (..), Judge0Error (..), SubmissionResult (..), submitAndWait)
import Network.HTTP.Types (statusCode, status429)
import Network.Socket (SockAddr (..), hostAddressToTuple, hostAddress6ToTuple)
import Network.Wai (Request, pathInfo, remoteHost, requestHeaders, requestMethod, responseStatus, responseLBS)
import Network.Wai.Middleware.Cors
import qualified Schema
import Schema (HintList (..))
import Servant

-- Rate limiter: per-IP sliding window (count, window-start)

type RateLimiter = TVar (Map Text (Int, UTCTime))

-- Sliding-window length, shared by the limiter and the reaper so they can't drift.
rateLimitWindowSeconds :: NominalDiffTime
rateLimitWindowSeconds = 60

-- A reaper prunes entries whose window has expired (BE-25); without it the map
-- grows one permanent entry per distinct key forever.
reaperIntervalMicros :: Int
reaperIntervalMicros = 300_000_000  -- 5 minutes

newRateLimiter :: IO RateLimiter
newRateLimiter = do
  limiter <- newTVarIO Map.empty
  void $ forkIO (reaper limiter)
  pure limiter

-- Periodically drop entries older than the window. Any key older than the
-- window would be reset on its next request anyway, so pruning is lossless.
reaper :: RateLimiter -> IO ()
reaper limiter = forever $ do
  threadDelay reaperIntervalMicros
  now <- getCurrentTime
  atomically $ modifyTVar' limiter $
    Map.filter (\(_, windowStart) -> diffUTCTime now windowStart < rateLimitWindowSeconds)

checkAndIncrement :: RateLimiter -> Int -> Text -> UTCTime -> STM Bool
checkAndIncrement limiter maxPerMin ip now = do
  m <- readTVar limiter
  let (count, windowStart) = maybe (0, now) id (Map.lookup ip m)
      elapsed              = diffUTCTime now windowStart
  if elapsed >= rateLimitWindowSeconds
    then writeTVar limiter (Map.insert ip (1, now) m)      >> pure True
    else if count >= maxPerMin
           then pure False
           else writeTVar limiter (Map.insert ip (count + 1, windowStart) m) >> pure True

-- The rate-limit key: prefer Fly's trusted client-IP header (BE-24). Behind
-- Fly's edge proxy, remoteHost is the proxy address, not the client, so it
-- collapses every user into one bucket. Fly-Client-IP is set by the platform
-- and is not client-spoofable the way a raw X-Forwarded-For would be; fall back
-- to the socket peer only when the header is absent (e.g. local dev).
clientIp :: Request -> Text
clientIp req =
  case lookup "Fly-Client-IP" (requestHeaders req) of
    Just ip -> TE.decodeUtf8 ip
    Nothing -> sockAddrIp (remoteHost req)

sockAddrIp :: SockAddr -> Text
sockAddrIp (SockAddrInet _ addr) =
  let (a, b, c, d) = hostAddressToTuple addr
  in T.intercalate "." (map (T.pack . show) [a, b, c, d])
sockAddrIp (SockAddrInet6 _ _ addr _) =
  let (a, b, c, d, e, f, g, h) = hostAddress6ToTuple addr
  in T.intercalate ":" (map (T.pack . show) [a, b, c, d, e, f, g, h])
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
  , exerciseDateAdded   = fmap (T.pack . show) (Schema.exerciseDateAdded ex)
  }

toChapterResponse :: Entity Schema.Chapter -> [Entity Schema.Exercise] -> ChapterResponse
toChapterResponse (Entity _ ch) exs = ChapterResponse
  { chapterSlug        = Schema.chapterSlug ch
  , chapterTitle       = Schema.chapterTitle ch
  , chapterDescription = Schema.chapterDescription ch
  , chapterLesson      = maybe "" id (Schema.chapterLesson ch)
  , chapterExercises   = map (toExerciseClient (Schema.chapterSlug ch)) exs
  , chapterDateAdded   = fmap (T.pack . show) (Schema.chapterDateAdded ch)
  }

-- Handlers

healthHandler :: ConnectionPool -> Handler HealthResponse
healthHandler pool = do
  result <- liftIO $ (try (runSqlPool (rawSql "SELECT 1" [] :: SqlPersistT IO [Single Int]) pool) :: IO (Either SomeException [Single Int]))
  case result of
    Left err -> do
      liftIO $ putStrLn $ "health: db check failed: " <> show err
      jsonError err503 "database unreachable" "db_error"
    Right _ -> pure $ HealthResponse { status = "ok" }

meHandler :: AuthEnv -> ConnectionPool -> Maybe Text -> Handler MeResponse
meHandler authEnv pool mAuth = do
  userId <- requireUser authEnv pool mAuth
  mUser  <- liftIO $ runSqlPool (get userId) pool
  case mUser of
    Nothing   -> jsonError err500 "user not found" "internal_error"
    Just user -> pure MeResponse
      { meId        = fromSqlKey userId
      , meUsername  = Schema.userUsername user
      , meAvatarUrl = Schema.userAvatarUrl user
      , meEmail     = Schema.userEmail user
      }

exercisesListHandler :: Bool -> ConnectionPool -> Handler ExercisesListResponse
exercisesListHandler showDraft pool = do
  let liveOnly f = if showDraft then [] else [f !=. Nothing]
  chapters  <- liftIO $ runSqlPool (selectList (liveOnly Schema.ChapterDateAdded)  [Asc Schema.ChapterOrderNum]) pool
  exercises <- liftIO $ runSqlPool (selectList (liveOnly Schema.ExerciseDateAdded) [Asc Schema.ExerciseOrderInChapter]) pool
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

submitHandler :: Judge0Config -> ConnectionPool -> AuthEnv -> RateLimiter -> Int -> Maybe Text -> SubmitRequest -> Handler SubmitResponse
submitHandler cfg pool authEnv userLimiter rateLimitPerUser mAuth req = do
  userId <- requireUser authEnv pool mAuth
  now0   <- liftIO getCurrentTime
  let userKey = T.pack (show (fromSqlKey userId))
  userAllowed <- liftIO $ atomically $ checkAndIncrement userLimiter rateLimitPerUser userKey now0
  when (not userAllowed) $
    throwError err429
      { errBody    = encode (object ["error" .= ("rate limit exceeded" :: Text), "code" .= ("rate_limited" :: Text)])
      , errHeaders = [("Content-Type", "application/json"), ("Retry-After", "60")]
      }
  let eid  = submitExerciseId req
      code = submitCode req
  if T.length code > 50_000
    then jsonError err413 "code exceeds 50KB limit" "too_large"
    else do
      mEx <- liftIO $ runSqlPool (getBy (Schema.UniqueExerciseSlug eid)) pool
      (exerciseKey, hiddenTests) <- case mEx of
        Nothing       -> jsonError err404 "exercise not found" "not_found"
        Just (Entity key exVal) -> pure (key, Schema.exerciseHiddenTests exVal)
      judge0Result <- liftIO $ submitAndWait cfg eid code hiddenTests
      result <- case judge0Result of
        Left (Judge0Unreachable _) -> jsonError err502 "evaluation service unavailable" "sandbox_unavailable"
        Left Judge0PollTimeout     -> jsonError err504 "evaluation service timed out"    "sandbox_timeout"
        Left (Judge0ParseError _)  -> jsonError err500 "unexpected evaluation response"  "internal_error"
        Right r                    -> pure r
      now    <- liftIO getCurrentTime
      liftIO $ runSqlPool (do
        insert_ Schema.Submission
          { Schema.submissionUserId      = Just userId
          , Schema.submissionExerciseId  = exerciseKey
          , Schema.submissionCode        = code
          , Schema.submissionStatus      = srStatus result
          , Schema.submissionOutput      = srOutput result
          , Schema.submissionPassedCount = srPassedCount result
          , Schema.submissionFailedCount = srFailedCount result
          , Schema.submissionCreatedAt   = now
          }
        upsertProgress userId exerciseKey (srStatus result) now
        ) pool
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
      , histCode        = Schema.submissionCode sub
      }

progressHandler :: Bool -> AuthEnv -> ConnectionPool -> Maybe Text -> Handler ProgressResponse
progressHandler showDraft authEnv pool mAuth = do
  userId    <- requireUser authEnv pool mAuth
  chapters  <- liftIO $ runSqlPool (selectList [] [Asc Schema.ChapterOrderNum]) pool
  let liveOnly f = if showDraft then [] else [f !=. Nothing]
  exercises <- liftIO $ runSqlPool (selectList (liveOnly Schema.ExerciseDateAdded) []) pool
  progresses <- liftIO $ runSqlPool
    (selectList [Schema.UserProgressUserId ==. userId] [])
    pool
  let chapOrder = Map.fromList
        [(entityKey c, i) | (c, i) <- zip chapters [0 :: Int ..]]
      progMap = Map.fromList
        [(Schema.userProgressExerciseId (entityVal p), entityVal p) | p <- progresses]
      orderedExs = sortBy
        (\(Entity _ a) (Entity _ b) ->
          let ci = Map.findWithDefault 0 (Schema.exerciseChapterId a) chapOrder
              cj = Map.findWithDefault 0 (Schema.exerciseChapterId b) chapOrder
          in compare ci cj <> compare (Schema.exerciseOrderInChapter a) (Schema.exerciseOrderInChapter b))
        exercises
  pure $ ProgressResponse { progressItems = map (toItem progMap) orderedExs }
  where
    toItem progMap (Entity exKey ex) =
      case Map.lookup exKey progMap of
        Just up -> ProgressItem
          { progressExerciseId    = Schema.exerciseSlug ex
          , progressStatus        = progressStatusToText (Schema.userProgressStatus up)
          , progressFirstPassedAt = Schema.userProgressFirstPassedAt up
          , progressLastSubmitted = Just (Schema.userProgressLastSubmittedAt up)
          }
        Nothing -> ProgressItem
          { progressExerciseId    = Schema.exerciseSlug ex
          , progressStatus        = "not_started"
          , progressFirstPassedAt = Nothing
          , progressLastSubmitted = Nothing
          }

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

server :: Bool -> Judge0Config -> ConnectionPool -> AuthEnv -> RateLimiter -> Int -> Server API
server showDraft cfg pool authEnv userLimiter rateLimitPerUser =
  healthHandler pool
    :<|> meHandler authEnv pool
    :<|> (exercisesListHandler showDraft pool :<|> exerciseByIdHandler pool)
    :<|> submitHandler cfg pool authEnv userLimiter rateLimitPerUser
    :<|> submissionHistoryHandler pool authEnv
    :<|> progressHandler showDraft authEnv pool

corsPolicy :: CorsResourcePolicy
corsPolicy = simpleCorsResourcePolicy
  { corsOrigins        = Nothing
  , corsMethods        = ["GET", "POST", "OPTIONS"]
  , corsRequestHeaders = ["Content-Type", "Authorization"]
  }

app :: Bool -> Judge0Config -> RateLimiter -> Int -> RateLimiter -> Int -> ConnectionPool -> AuthEnv -> Application
app showDraft cfg ipLimiter rateLimitPerIp userLimiter rateLimitPerUser pool authEnv =
  cors (const (Just corsPolicy)) $
  loggingMiddleware $
  rateLimitMiddleware ipLimiter rateLimitPerIp $
  serve (Proxy :: Proxy API) (server showDraft cfg pool authEnv userLimiter rateLimitPerUser)

-- Middleware

rateLimitMiddleware :: RateLimiter -> Int -> Application -> Application
rateLimitMiddleware limiter maxPerMin inner req send =
  if requestMethod req == "POST" && pathInfo req == ["api", "submissions"]
    then do
      now <- getCurrentTime
      let ip = clientIp req
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
