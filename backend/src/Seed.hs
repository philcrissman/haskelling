module Seed where

import Control.Exception (SomeException, try)
import Control.Monad (filterM, forM, forM_)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:), (.:?))
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BSL
import Data.List (nubBy, sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Data.Text.IO qualified as TIO
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Persist (Entity (..), getBy, insert, insert_, update, (=.))
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Database.Persist.Sql (SqlPersistT)
import Schema
import System.Directory (doesDirectoryExist, listDirectory)
import System.Exit (die)
import System.FilePath ((</>))

-- exercise.json (per exercise directory)

data ExerciseMeta = ExerciseMeta
  { emOrder             :: Int
  , emTitle             :: Text
  , emLearningObjective :: Text
  , emHints             :: [Text]
  , emDateAdded         :: Maybe Day
  }

instance FromJSON ExerciseMeta where
  parseJSON = withObject "ExerciseMeta" $ \o ->
    ExerciseMeta
      <$> o .:  "order"
      <*> o .:  "title"
      <*> o .:  "learning_objective"
      <*> o .:  "hints"
      <*> o .:? "date_added"

-- chapter.json (per chapter directory)

data ChapterMeta = ChapterMeta
  { cmOrder     :: Int
  , cmDateAdded :: Maybe Day
  }

instance FromJSON ChapterMeta where
  parseJSON = withObject "ChapterMeta" $ \o ->
    ChapterMeta
      <$> o .:  "order"
      <*> o .:? "date_added"

-- In-memory exercise record assembled from files

data CurriculumExercise = CurriculumExercise
  { ceId                 :: Text
  , ceTitle              :: Text
  , ceChapter            :: Text
  , ceChapterOrder       :: Int
  , ceChapterDateAdded   :: Maybe Day
  , ceOrder              :: Int
  , ceLearningObjective  :: Text
  , ceStubCode           :: Text
  , ceHiddenTestSuite    :: Text
  , ceCanonicalSolution  :: Text
  , ceHints              :: [Text]
  , ceDateAdded          :: Maybe Day
  }
  deriving (Show)

-- Chapter metadata: (title, description)

chapterMeta :: Text -> (Text, Text)
chapterMeta "starting-out"     = ("Starting Out",      "First steps in Haskell: arithmetic, booleans, functions, lists, ranges, list comprehensions, and tuples. Follows LYAH chapter 2.")
chapterMeta "types-and-typeclasses" = ("Types and Typeclasses", "Reading types, polymorphism with type variables, and the core typeclasses: Eq, Ord, Show, Read, Enum, Bounded, and Num. Follows LYAH chapter 3.")
chapterMeta "syntax-in-functions" = ("Syntax in Functions", "Ways to write a function body: pattern matching, guards, where, let, and case expressions. Follows LYAH chapter 4.")
chapterMeta slug               = (slug, "")

-- Read lesson markdown for a chapter (returns empty string if file missing)

readLesson :: FilePath -> Text -> IO Text
readLesson lessonsDir slug = do
  let path = lessonsDir <> "/" <> T.unpack slug <> ".md"
  result <- try (fmap decodeUtf8 (BS.readFile path)) :: IO (Either SomeException Text)
  pure $ either (const "") id result

-- Load all exercises from curriculum/exercises/

loadExercisesFromDir :: FilePath -> IO [CurriculumExercise]
loadExercisesFromDir curriculumDir = do
  let exercisesDir = curriculumDir </> "exercises"
  chapterSlugs <- listDirectory exercisesDir
                    >>= filterM (\d -> doesDirectoryExist (exercisesDir </> d))
  fmap concat $ forM chapterSlugs $ \chSlug -> do
    let chDir = exercisesDir </> chSlug
    chOrderBytes <- BSL.readFile (chDir </> "chapter.json")
    chMeta <- case eitherDecode chOrderBytes of
      Left err -> die $ "Failed to parse chapter.json in " <> chDir <> ": " <> err
      Right m  -> pure m
    let chOrder     = cmOrder chMeta
        chDateAdded = cmDateAdded chMeta
    exerciseSlugs <- listDirectory chDir
                       >>= filterM (\d -> doesDirectoryExist (chDir </> d))
    forM exerciseSlugs $ \exSlug -> do
      let exDir = chDir </> exSlug
      metaBytes <- BSL.readFile (exDir </> "exercise.json")
      meta <- case eitherDecode metaBytes of
        Left err -> die $ "Failed to parse exercise.json in " <> exDir <> ": " <> err
        Right m  -> pure m
      stub     <- TIO.readFile (exDir </> "stub.hs")
      tests    <- TIO.readFile (exDir </> "tests.hs")
      solution <- TIO.readFile (exDir </> "solution.hs")
      pure CurriculumExercise
        { ceId                = T.pack exSlug
        , ceTitle             = emTitle meta
        , ceChapter           = T.pack chSlug
        , ceChapterOrder      = chOrder
        , ceChapterDateAdded  = chDateAdded
        , ceOrder             = emOrder meta
        , ceLearningObjective = emLearningObjective meta
        , ceStubCode          = stub
        , ceHiddenTestSuite   = tests
        , ceCanonicalSolution = solution
        , ceHints             = emHints meta
        , ceDateAdded         = emDateAdded meta
        }

-- Upsert helpers

upsertChapter :: Text -> Text -> Text -> Maybe Text -> Int -> Maybe Day -> SqlPersistT IO ChapterId
upsertChapter slug title desc lesson orderNum dateAdded = do
  mExisting <- getBy (UniqueChapterSlug slug)
  case mExisting of
    Nothing ->
      insert (Chapter slug title desc lesson orderNum dateAdded)
    Just (Entity key _) -> do
      update key
        [ ChapterTitle       =. title
        , ChapterDescription =. desc
        , ChapterLesson      =. lesson
        , ChapterOrderNum    =. orderNum
        , ChapterDateAdded   =. dateAdded
        ]
      pure key

upsertExercise :: CurriculumExercise -> ChapterId -> UTCTime -> SqlPersistT IO ()
upsertExercise ce chapterId now = do
  let hints = HintList (ceHints ce)
  mExisting <- getBy (UniqueExerciseSlug (ceId ce))
  case mExisting of
    Nothing ->
      insert_ $
        Exercise
          { exerciseSlug              = ceId ce
          , exerciseTitle             = ceTitle ce
          , exerciseChapterId         = chapterId
          , exerciseOrderInChapter    = ceOrder ce
          , exerciseLearningObjective = ceLearningObjective ce
          , exerciseStubCode          = ceStubCode ce
          , exerciseHiddenTests       = ceHiddenTestSuite ce
          , exerciseCanonicalSolution = ceCanonicalSolution ce
          , exerciseHints             = hints
          , exerciseDateAdded         = ceDateAdded ce
          , exerciseCreatedAt         = now
          , exerciseUpdatedAt         = now
          }
    Just (Entity key _) ->
      update
        key
        [ ExerciseChapterId         =. chapterId
        , ExerciseTitle             =. ceTitle ce
        , ExerciseOrderInChapter    =. ceOrder ce
        , ExerciseLearningObjective =. ceLearningObjective ce
        , ExerciseStubCode          =. ceStubCode ce
        , ExerciseHiddenTests       =. ceHiddenTestSuite ce
        , ExerciseCanonicalSolution =. ceCanonicalSolution ce
        , ExerciseHints             =. hints
        , ExerciseDateAdded         =. ceDateAdded ce
        , ExerciseUpdatedAt         =. now
        ]

-- Main seed action

seedAll :: FilePath -> [CurriculumExercise] -> UTCTime -> SqlPersistT IO ()
seedAll lessonsDir exercises now = do
  let uniqueChapters =
        nubBy (\a b -> ceChapter a == ceChapter b) $
          sortOn ceChapterOrder exercises

  chapterIds <- Map.fromList <$> forM uniqueChapters (\ex -> do
    let slug      = ceChapter ex
        orderNum  = ceChapterOrder ex
        dateAdded = ceChapterDateAdded ex
        (title, desc) = chapterMeta slug
    rawLesson <- liftIO $ readLesson lessonsDir slug
    let lesson = if T.null rawLesson then Nothing else Just rawLesson
    key <- upsertChapter slug title desc lesson orderNum dateAdded
    pure (slug, key))

  forM_ exercises $ \ex ->
    upsertExercise ex (chapterIds Map.! ceChapter ex) now

-- Entry point

seedFromDir :: FilePath -> ConnectionPool -> IO ()
seedFromDir curriculumDir pool = do
  exercises <- loadExercisesFromDir curriculumDir
  let lessonsDir = curriculumDir </> "lessons"
  now <- getCurrentTime
  runSqlPool (seedAll lessonsDir exercises now) pool
  putStrLn $ "haskelling: seeded " <> show (length exercises) <> " exercises"
