module Seed where

import Control.Monad (forM, forM_)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:))
import Data.ByteString.Lazy qualified as BSL
import Data.List (nubBy)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)
import Database.Persist (Entity (..), getBy, insert, insert_, update, (=.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Database.Persist.Sql (SqlPersistT)
import Schema
import System.Exit (die)

-- Parsing CURRICULUM.json

data CurriculumExercise = CurriculumExercise
  { ceId                :: Text
  , ceTitle             :: Text
  , ceChapter           :: Text
  , ceOrder             :: Int
  , ceLearningObjective :: Text
  , ceStubCode          :: Text
  , ceHiddenTestSuite   :: Text
  , ceCanonicalSolution :: Text
  , ceHints             :: [Text]
  }
  deriving (Show)

instance FromJSON CurriculumExercise where
  parseJSON = withObject "CurriculumExercise" $ \o ->
    CurriculumExercise
      <$> o .: "id"
      <*> o .: "title"
      <*> o .: "chapter"
      <*> o .: "order"
      <*> o .: "learning_objective"
      <*> o .: "stub_code"
      <*> o .: "hidden_test_suite"
      <*> o .: "canonical_solution"
      <*> o .: "hints"

-- Chapter metadata not in CURRICULUM.json

chapterMeta :: Text -> (Text, Text)
chapterMeta "basics"           = ("Basics", "Core Haskell syntax and fundamental concepts.")
chapterMeta "lists"            = ("Lists", "Working with Haskell's built-in list type.")
chapterMeta "types"            = ("Types", "Haskell's type system, Maybe, and custom data types.")
chapterMeta "pattern-matching" = ("Pattern Matching", "Deconstructing values with pattern matching and case expressions.")
chapterMeta "recursion"        = ("Recursion", "Recursive functions and tail recursion.")
chapterMeta "typeclasses"      = ("Type Classes", "Haskell's typeclass system: Show, Eq, Functor, and more.")
chapterMeta slug               = (slug, "")

-- Upsert helpers

upsertChapter :: Text -> Text -> Text -> Int -> SqlPersistT IO ChapterId
upsertChapter slug title desc orderNum = do
  mExisting <- getBy (UniqueChapterSlug slug)
  case mExisting of
    Nothing -> insert (Chapter slug title desc orderNum)
    Just (Entity key _) -> do
      update key [ChapterTitle =. title, ChapterDescription =. desc, ChapterOrderNum =. orderNum]
      pure key

upsertExercise :: CurriculumExercise -> ChapterId -> UTCTime -> SqlPersistT IO ()
upsertExercise ce chapterId now = do
  let hints = HintList (ceHints ce)
  mExisting <- getBy (UniqueExerciseSlug (ceId ce))
  case mExisting of
    Nothing ->
      insert_ $
        Exercise
          { exerciseSlug = ceId ce
          , exerciseTitle = ceTitle ce
          , exerciseChapterId = chapterId
          , exerciseOrderInChapter = ceOrder ce
          , exerciseLearningObjective = ceLearningObjective ce
          , exerciseStubCode = ceStubCode ce
          , exerciseHiddenTests = ceHiddenTestSuite ce
          , exerciseCanonicalSolution = ceCanonicalSolution ce
          , exerciseHints = hints
          , exerciseCreatedAt = now
          , exerciseUpdatedAt = now
          }
    Just (Entity key _) ->
      update
        key
        [ ExerciseTitle =. ceTitle ce
        , ExerciseOrderInChapter =. ceOrder ce
        , ExerciseLearningObjective =. ceLearningObjective ce
        , ExerciseStubCode =. ceStubCode ce
        , ExerciseHiddenTests =. ceHiddenTestSuite ce
        , ExerciseCanonicalSolution =. ceCanonicalSolution ce
        , ExerciseHints =. hints
        , ExerciseUpdatedAt =. now
        ]

-- Main seed action

seedAll :: [CurriculumExercise] -> UTCTime -> SqlPersistT IO ()
seedAll exercises now = do
  -- Unique chapters in first-appearance order (preserves JSON ordering)
  let uniqueChapters =
        zip [1 ..] $
          nubBy (\a b -> ceChapter a == ceChapter b) exercises

  -- Upsert chapters; build slug → ChapterId map
  chapterIds <- Map.fromList <$> forM uniqueChapters (\(orderNum, ex) -> do
    let slug = ceChapter ex
        (title, desc) = chapterMeta slug
    key <- upsertChapter slug title desc orderNum
    pure (slug, key))

  -- Upsert all exercises
  forM_ exercises $ \ex ->
    upsertExercise ex (chapterIds Map.! ceChapter ex) now

-- Entry point

seedFromFile :: FilePath -> ConnectionPool -> IO ()
seedFromFile path pool = do
  content <- BSL.readFile path
  exercises <- case eitherDecode content of
    Left err -> die $ "Failed to parse CURRICULUM.json: " <> err
    Right xs -> pure xs
  now <- getCurrentTime
  runSqlPool (seedAll exercises now) pool
  putStrLn $ "haskelling: seeded " <> show (length exercises) <> " exercises"
