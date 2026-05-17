{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API where

import Data.Aeson (ToJSON (..), object, (.=))
import Data.Text (Text)
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
    [ "id"                 .= exerciseId e
    , "title"              .= exerciseTitle e
    , "chapter"            .= exerciseChapter e
    , "order"              .= exerciseOrder e
    , "learning_objective" .= exerciseLearningObj e
    , "stub_code"          .= exerciseStubCode e
    , "hints"              .= exerciseHints e
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

-- API type

type HealthAPI = "health" :> Get '[JSON] HealthResponse

type ExercisesAPI =
       "api" :> "exercises" :> Get '[JSON] ExercisesListResponse
  :<|> "api" :> "exercises" :> Capture "id" Text :> Get '[JSON] ExerciseClient

type API = HealthAPI :<|> ExercisesAPI
