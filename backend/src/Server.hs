{-# LANGUAGE DataKinds #-}

module Server where

import API
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
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

server :: Server API
server = healthHandler :<|> exercisesListHandler :<|> exerciseByIdHandler

app :: Application
app = serve (Proxy :: Proxy API) server
