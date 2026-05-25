{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Schema where

import Data.Aeson (eitherDecodeStrict, encode)
import Data.Bifunctor (first)
import Data.ByteString.Lazy (toStrict)
import Data.Text (Text, pack)
import Data.Time (Day, UTCTime)
import Database.Persist (LiteralType (..), PersistField (..), PersistValue (..))
import Database.Persist.Sql (PersistFieldSql (..), SqlType (..))
import Database.Persist.TH

-- HintList: [Text] stored as JSONB.
-- Uses a newtype to avoid conflicting with Persistent's built-in [a] instance.

newtype HintList = HintList {getHints :: [Text]}
  deriving (Show, Eq)

instance PersistField HintList where
  toPersistValue (HintList xs) =
    PersistLiteral_ DbSpecific (toStrict (encode xs))
  fromPersistValue (PersistByteString bs) =
    first pack $ HintList <$> eitherDecodeStrict bs
  fromPersistValue (PersistLiteral_ _ bs) =
    first pack $ HintList <$> eitherDecodeStrict bs
  fromPersistValue v =
    Left $ "Expected JSONB for HintList, got: " <> pack (show v)

instance PersistFieldSql HintList where
  sqlType _ = SqlOther "jsonb"

-- Enum types stored as TEXT via show/read (e.g. "StatusPass", "Passed").

data SubmissionStatus
  = StatusPass
  | StatusFail
  | StatusCompileError
  | StatusTimeout
  | StatusRuntimeError
  | StatusError
  deriving (Show, Eq, Read, Enum, Bounded)

derivePersistField "SubmissionStatus"

data ProgressStatus
  = NotStarted
  | Attempted
  | Passed
  deriving (Show, Eq, Read, Enum, Bounded)

derivePersistField "ProgressStatus"

-- Entity definitions

share
  [mkPersist sqlSettings, mkMigrate "migrateAll"]
  [persistLowerCase|
User
  clerkId     Text
  username    Text
  email       Text Maybe
  avatarUrl   Text Maybe
  createdAt   UTCTime
  updatedAt   UTCTime
  UniqueClerkId clerkId
  deriving Show Eq

Chapter
  slug        Text
  title       Text
  description Text
  lesson      Text Maybe
  orderNum    Int
  dateAdded   Day Maybe
  UniqueChapterSlug slug
  deriving Show Eq

Exercise
  slug              Text
  title             Text
  chapterId         ChapterId
  orderInChapter    Int
  learningObjective Text
  stubCode          Text
  hiddenTests       Text
  canonicalSolution Text
  hints             HintList
  dateAdded         Day Maybe
  createdAt         UTCTime
  updatedAt         UTCTime
  UniqueExerciseSlug slug
  deriving Show Eq

Submission
  userId        UserId Maybe    -- nullable until auth wired in (Phase 9 / BE-13)
  exerciseId    ExerciseId
  code          Text
  status        SubmissionStatus
  output        Text
  passedCount   Int
  failedCount   Int
  createdAt     UTCTime
  deriving Show Eq

UserProgress
  userId          UserId
  exerciseId      ExerciseId
  status          ProgressStatus
  firstPassedAt   UTCTime Maybe
  lastSubmittedAt UTCTime
  UniqueUserExercise userId exerciseId
  deriving Show Eq
|]
