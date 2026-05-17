{-# LANGUAGE DataKinds #-}

module Server where

import API
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Judge0 (Judge0Config (..), SubmissionResult (..), submitAndWait)
import Servant

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
    { chapterSlug = "basics"
    , chapterTitle = "Basics"
    , chapterExercises = [helloWorldExercise]
    }

-- Error helper

jsonError :: ServerError -> Text -> Text -> Handler a
jsonError base msg code =
  throwError
    base
      { errBody = encode (object ["error" .= msg, "code" .= code])
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
  -- Code size guard (50 KB)
  if fromIntegral (length (show code)) > (50_000 :: Int)
    then jsonError err413 "code exceeds 50KB limit" "too_large"
    else do
      -- Hardcoded test lookup (replaced by DB in BE-08)
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

app :: Judge0Config -> Application
app cfg = serve (Proxy :: Proxy API) (server cfg)
