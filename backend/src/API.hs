{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Schema (SubmissionStatus (..))
import Servant

-- Health

newtype HealthResponse = HealthResponse {status :: Text}

instance ToJSON HealthResponse where
  toJSON r = object ["status" .= status r]

-- Me

data MeResponse = MeResponse
  { meId        :: Int64
  , meUsername  :: Text
  , meAvatarUrl :: Maybe Text
  , meEmail     :: Maybe Text
  }

instance ToJSON MeResponse where
  toJSON r = object
    [ "id"        .= meId r
    , "username"  .= meUsername r
    , "avatarUrl" .= meAvatarUrl r
    , "email"     .= meEmail r
    ]

-- Exercises (client-facing schema — hiddenTests and canonicalSolution never included)

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
  { chapterSlug        :: Text
  , chapterTitle       :: Text
  , chapterDescription :: Text
  , chapterLesson      :: Text
  , chapterExercises   :: [ExerciseClient]
  }

instance ToJSON ChapterResponse where
  toJSON c = object
    [ "slug"        .= chapterSlug c
    , "title"       .= chapterTitle c
    , "description" .= chapterDescription c
    , "lesson"      .= chapterLesson c
    , "exercises"   .= chapterExercises c
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

-- Submission history (BE-10)

data SubmissionHistoryItem = SubmissionHistoryItem
  { histId          :: Int64
  , histStatus      :: Text
  , histOutput      :: Text
  , histPassedCount :: Int
  , histFailedCount :: Int
  , histCreatedAt   :: UTCTime
  }

instance ToJSON SubmissionHistoryItem where
  toJSON h = object
    [ "id"          .= histId h
    , "status"      .= histStatus h
    , "output"      .= histOutput h
    , "passedCount" .= histPassedCount h
    , "failedCount" .= histFailedCount h
    , "createdAt"   .= histCreatedAt h
    ]

newtype SubmissionHistoryResponse = SubmissionHistoryResponse
  { historySubmissions :: [SubmissionHistoryItem] }

instance ToJSON SubmissionHistoryResponse where
  toJSON r = object ["submissions" .= historySubmissions r]

-- Progress (BE-16) — empty until auth is wired (Phase 9)

data ProgressItem = ProgressItem
  { progressExerciseId     :: Text
  , progressStatus         :: Text
  , progressFirstPassedAt  :: Maybe UTCTime
  , progressLastSubmitted  :: Maybe UTCTime
  }

instance ToJSON ProgressItem where
  toJSON p = object
    [ "exerciseId"      .= progressExerciseId p
    , "status"          .= progressStatus p
    , "firstPassedAt"   .= progressFirstPassedAt p
    , "lastSubmittedAt" .= progressLastSubmitted p
    ]

newtype ProgressResponse = ProgressResponse
  { progressItems :: [ProgressItem] }

instance ToJSON ProgressResponse where
  toJSON r = object ["progress" .= progressItems r]

-- Status helpers

statusToText :: SubmissionStatus -> Text
statusToText StatusPass         = "pass"
statusToText StatusFail         = "fail"
statusToText StatusCompileError = "compile_error"
statusToText StatusTimeout      = "timeout"
statusToText StatusRuntimeError = "runtime_error"
statusToText StatusError        = "error"

-- API type

type HealthAPI = "health" :> Get '[JSON] HealthResponse

type MeAPI =
  "api" :> "me"
    :> Header "Authorization" Text
    :> Get '[JSON] MeResponse

type ExercisesAPI =
       "api" :> "exercises" :> Get '[JSON] ExercisesListResponse
  :<|> "api" :> "exercises" :> Capture "id" Text :> Get '[JSON] ExerciseClient

type SubmissionsAPI =
  "api" :> "submissions"
    :> Header "Authorization" Text
    :> ReqBody '[JSON] SubmitRequest
    :> Post '[JSON] SubmitResponse

type SubmissionHistoryAPI =
  "api" :> "exercises" :> Capture "id" Text :> "submissions"
    :> Header "Authorization" Text
    :> Get '[JSON] SubmissionHistoryResponse

type ProgressAPI =
  "api" :> "progress"
    :> Header "Authorization" Text
    :> Get '[JSON] ProgressResponse

type API =
       HealthAPI
  :<|> MeAPI
  :<|> ExercisesAPI
  :<|> SubmissionsAPI
  :<|> SubmissionHistoryAPI
  :<|> ProgressAPI
