{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Text (Text)
import Schema (SubmissionStatus (..))
import Servant

-- Health

newtype HealthResponse = HealthResponse {status :: Text}

instance ToJSON HealthResponse where
  toJSON r = object ["status" .= status r]

-- Exercises (client-facing schema — hidden_test_suite and canonical_solution never included)

data ExerciseClient = ExerciseClient
  { exerciseId          :: Text
  , exerciseTitle       :: Text
  , exerciseChapter     :: Text
  , exerciseOrder       :: Int
  , exerciseLearningObj :: Text
  , exerciseStubCode    :: Text
  , exerciseHints       :: [Text]
  }

instance ToJSON ExerciseClient where
  toJSON e = object
    [ "id"               .= exerciseId e
    , "title"            .= exerciseTitle e
    , "chapter"          .= exerciseChapter e
    , "order"            .= exerciseOrder e
    , "learningObjective" .= exerciseLearningObj e
    , "stubCode"         .= exerciseStubCode e
    , "hints"            .= exerciseHints e
    ]

data ChapterResponse = ChapterResponse
  { chapterSlug      :: Text
  , chapterTitle     :: Text
  , chapterExercises :: [ExerciseClient]
  }

instance ToJSON ChapterResponse where
  toJSON c = object
    [ "slug"      .= chapterSlug c
    , "title"     .= chapterTitle c
    , "exercises" .= chapterExercises c
    ]

newtype ExercisesListResponse = ExercisesListResponse
  { responseChapters :: [ChapterResponse]
  }

instance ToJSON ExercisesListResponse where
  toJSON r = object ["chapters" .= responseChapters r]

-- Submissions

data SubmitRequest = SubmitRequest
  { submitExerciseId :: Text
  , submitCode       :: Text
  }

instance FromJSON SubmitRequest where
  parseJSON = withObject "SubmitRequest" $ \o ->
    SubmitRequest <$> o .: "exerciseId" <*> o .: "code"

data SubmitResponse = SubmitResponse
  { submitStatus      :: Text
  , submitOutput      :: Text
  , submitPassedCount :: Int
  , submitFailedCount :: Int
  }

instance ToJSON SubmitResponse where
  toJSON r = object
    [ "status"       .= submitStatus r
    , "output"       .= submitOutput r
    , "passedCount"  .= submitPassedCount r
    , "failedCount"  .= submitFailedCount r
    ]

statusToText :: SubmissionStatus -> Text
statusToText StatusPass         = "pass"
statusToText StatusFail         = "fail"
statusToText StatusCompileError = "compile_error"
statusToText StatusTimeout      = "timeout"
statusToText StatusRuntimeError = "runtime_error"
statusToText StatusError        = "error"

-- API type

type HealthAPI = "health" :> Get '[JSON] HealthResponse

type ExercisesAPI =
       "api" :> "exercises" :> Get '[JSON] ExercisesListResponse
  :<|> "api" :> "exercises" :> Capture "id" Text :> Get '[JSON] ExerciseClient

type SubmissionsAPI =
  "api" :> "submissions" :> ReqBody '[JSON] SubmitRequest :> Post '[JSON] SubmitResponse

type API = HealthAPI :<|> ExercisesAPI :<|> SubmissionsAPI
