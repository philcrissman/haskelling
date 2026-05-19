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
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime, diffUTCTime, getCurrentTime)
import Judge0 (Judge0Config (..), SubmissionResult (..), submitAndWait)
import Network.HTTP.Types.Status (status429)
import Network.Socket (SockAddr (..), hostAddressToTuple)
import Network.Wai (pathInfo, remoteHost, requestMethod, responseLBS)
import Servant

-- Rate limiter: per-IP sliding window (count, window-start)

type RateLimiter = TVar (Map Text (Int, UTCTime))

newRateLimiter :: IO RateLimiter
newRateLimiter = newTVarIO Map.empty

-- Returns True if the request is allowed, increments counter if so.
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

-- Hardcoded hello-world exercise (replaced by DB in BE-08)

helloWorldExercise :: ExerciseClient
helloWorldExercise =
  ExerciseClient
    { exerciseId = "hello-world"
    , exerciseTitle = "Hello, World!"
    , exerciseChapter = "basics"
    , exerciseOrder = 1
    , exerciseLearningObj = "Define a function that returns a fixed String value."
    , exerciseStubCode = "module HelloWorld where\n\ngreet :: String\ngreet = undefined"
    , exerciseHints =
        [ "A string literal in Haskell is written with double quotes."
        , "Replace undefined with the string value the function should return."
        , "Return the string \"Hello, World!\" exactly \8212 note the comma and exclamation mark."
        ]
    }

basicsChapter :: ChapterResponse
basicsChapter =
  ChapterResponse
    { chapterSlug        = "basics"
    , chapterTitle       = "Basics"
    , chapterDescription = "Core Haskell syntax and fundamental concepts."
    , chapterExercises   = [helloWorldExercise]
    }

-- Error helper

jsonError :: ServerError -> Text -> Text -> Handler a
jsonError base msg code =
  throwError
    base
      { errBody    = encode (object ["error" .= msg, "code" .= code])
      , errHeaders = [("Content-Type", "application/json")]
      }

-- Handlers

healthHandler :: Handler HealthResponse
healthHandler = return $ HealthResponse {status = "ok"}

exercisesListHandler :: Handler ExercisesListResponse
exercisesListHandler = return $ ExercisesListResponse {responseChapters = [basicsChapter]}

exerciseByIdHandler :: Text -> Handler ExerciseClient
exerciseByIdHandler eid
  | eid == "hello-world" = return helloWorldExercise
  | otherwise = jsonError err404 "exercise not found" "not_found"

-- Hardcoded hidden test suite for hello-world (replaced by DB lookup in BE-08)

helloWorldTests :: Text
helloWorldTests =
  "module Main where\n\
  \import System.Exit (exitFailure, exitSuccess)\n\
  \import HelloWorld\n\
  \\n\
  \assertEqual :: (Show a, Eq a) => String -> a -> a -> IO Bool\n\
  \assertEqual lbl got want\n\
  \  | got == want = putStrLn (\"  PASS: \" ++ lbl) >> return True\n\
  \  | otherwise   = putStrLn (\"  FAIL: \" ++ lbl) >> return False\n\
  \\n\
  \main :: IO ()\n\
  \main = do\n\
  \  results <- sequence\n\
  \    [ assertEqual \"greet returns Hello, World!\" greet \"Hello, World!\"\n\
  \    ]\n\
  \  let passed = length (filter id results)\n\
  \      failed  = length results - passed\n\
  \  putStrLn $ show (length results) ++ \" examples, \" ++ show failed ++ \" failures\"\n\
  \  if failed == 0 then exitSuccess else exitFailure\n"

submitHandler :: Judge0Config -> SubmitRequest -> Handler SubmitResponse
submitHandler cfg req = do
  let eid  = submitExerciseId req
      code = submitCode req
  if fromIntegral (length (show code)) > (50_000 :: Int)
    then jsonError err413 "code exceeds 50KB limit" "too_large"
    else do
      hiddenTests <- case eid of
        "hello-world" -> pure helloWorldTests
        _             -> jsonError err404 "exercise not found" "not_found"
      result <- liftIO $ submitAndWait cfg eid code hiddenTests
      pure SubmitResponse
        { submitStatus      = statusToText (srStatus result)
        , submitOutput      = srOutput result
        , submitPassedCount = srPassedCount result
        , submitFailedCount = srFailedCount result
        }

-- App

server :: Judge0Config -> Server API
server cfg =
  healthHandler
    :<|> (exercisesListHandler :<|> exerciseByIdHandler)
    :<|> submitHandler cfg

app :: Judge0Config -> RateLimiter -> Int -> Application
app cfg limiter rateLimit =
  rateLimitMiddleware limiter rateLimit $
  serve (Proxy :: Proxy API) (server cfg)

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
