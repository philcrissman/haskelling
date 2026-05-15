# Data Model

*Input: ADR-001, EVAL-SERVICE-DESIGN.md*

---

## Entity Relationship Diagram

```
┌─────────┐       ┌──────────┐       ┌────────────┐
│ Chapter │ 1───* │ Exercise │ *───* │    User    │
└─────────┘       └──────────┘       └────────────┘
                       │                    │
                       │                    │
                       └──────┬─────────────┘
                              │
                       ┌──────▼──────┐
                       │ Submission  │
                       └─────────────┘
                              │
                    (denormalized into)
                              │
                       ┌──────▼──────┐
                       │UserProgress │
                       └─────────────┘
```

### Relationships

| Entity | Relationship | Entity |
|--------|-------------|--------|
| Chapter | has many | Exercise |
| Exercise | has many | Submission |
| User | has many | Submission |
| User | has one per Exercise | UserProgress |
| Exercise | has one per User | UserProgress |

---

## Design Notes

### Primary keys
All entities use `Int64` auto-increment primary keys. Persistent generates these by default and they require no additional configuration. UUID keys are a valid alternative for publicly-exposed IDs but add setup overhead (custom `PersistField` instances, `uuid` package) that isn't justified at this stage.

### Sensitive fields
`Exercise` has two fields that must never leave the server: `hiddenTests` and `canonicalSolution`. These are stored in the database for runtime use but are excluded at the Haskell type level — a separate `ExerciseResponse` type (without those fields) is used for all API serialization. The database stores them; the type system enforces the boundary.

### Hints storage
`hints` is a `[Text]` stored as JSONB. It is always read and written as a complete ordered array, never queried element-by-element, making JSONB the right fit. A `PersistField` instance backed by Aeson handles serialization.

### Exercise seeding
Exercises are authored as git-tracked files and seeded into the database on each deploy using an upsert on `UniqueExerciseSlug`. `updatedAt` reflects the last seed. The database is the runtime source of truth; the files are authoritative for authoring.

### Module naming
Exercise slugs map to Haskell module names via PascalCase conversion (`hello-world` → `HelloWorld`). This is a hard convention enforced at seed time — the slug determines the module name, and the hidden test suite imports that module by name.

---

## Persistent Entity Definitions

```haskell
-- In Schema.hs, using Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|

User
  githubId    Int64
  username    Text
  email       Text Maybe
  avatarUrl   Text Maybe
  createdAt   UTCTime
  updatedAt   UTCTime
  UniqueGithubId githubId
  deriving Show Eq

Chapter
  slug        Text
  title       Text
  description Text
  orderNum    Int
  UniqueChapterSlug slug
  deriving Show Eq

Exercise
  slug              Text
  title             Text
  chapterId         ChapterId
  orderInChapter    Int
  learningObjective Text
  stubCode          Text
  hiddenTests       Text        -- never serialized to client
  canonicalSolution Text        -- never serialized to client or sent to Judge0
  hints             [Text]      -- stored as JSONB; 1–5 entries
  createdAt         UTCTime
  updatedAt         UTCTime
  UniqueExerciseSlug slug
  deriving Show Eq

Submission
  userId        UserId
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
```

### Custom field types

```haskell
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
```

`derivePersistField` (from `persistent`) stores these as `TEXT` using `show`/`read`, giving readable values in the database (`"StatusPass"`, `"Passed"`, etc.) without requiring a custom PostgreSQL enum type.

### PersistField for [Text]

```haskell
-- Stored as JSONB via Aeson. Add to Schema.hs alongside the entity definitions.
instance PersistField [Text] where
  toPersistValue = PersistDbSpecific . toStrict . encode
  fromPersistValue (PersistDbSpecific bs) =
    either (Left . pack) Right (eitherDecodeStrict bs)
  fromPersistValue _ = Left "Expected PersistDbSpecific for [Text]"

instance PersistFieldSql [Text] where
  sqlType _ = SqlOther "jsonb"
```

---

## Migration SQL

This is the SQL that `runMigration migrateAll` generates. Commit this for review before running in production; use `printMigration` to produce it.

```sql
CREATE TABLE "user" (
  "id"          BIGSERIAL PRIMARY KEY,
  "github_id"   BIGINT    NOT NULL,
  "username"    TEXT      NOT NULL,
  "email"       TEXT,
  "avatar_url"  TEXT,
  "created_at"  TIMESTAMPTZ NOT NULL,
  "updated_at"  TIMESTAMPTZ NOT NULL,
  CONSTRAINT "unique_github_id" UNIQUE ("github_id")
);

CREATE TABLE "chapter" (
  "id"          BIGSERIAL PRIMARY KEY,
  "slug"        TEXT NOT NULL,
  "title"       TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "order_num"   INT  NOT NULL,
  CONSTRAINT "unique_chapter_slug" UNIQUE ("slug")
);

CREATE TABLE "exercise" (
  "id"                BIGSERIAL PRIMARY KEY,
  "slug"              TEXT NOT NULL,
  "title"             TEXT NOT NULL,
  "chapter_id"        BIGINT NOT NULL REFERENCES "chapter"("id"),
  "order_in_chapter"  INT  NOT NULL,
  "learning_objective" TEXT NOT NULL,
  "stub_code"         TEXT NOT NULL,
  "hidden_tests"      TEXT NOT NULL,
  "canonical_solution" TEXT NOT NULL,
  "hints"             JSONB NOT NULL,
  "created_at"        TIMESTAMPTZ NOT NULL,
  "updated_at"        TIMESTAMPTZ NOT NULL,
  CONSTRAINT "unique_exercise_slug" UNIQUE ("slug")
);

CREATE TABLE "submission" (
  "id"           BIGSERIAL PRIMARY KEY,
  "user_id"      BIGINT NOT NULL REFERENCES "user"("id"),
  "exercise_id"  BIGINT NOT NULL REFERENCES "exercise"("id"),
  "code"         TEXT   NOT NULL,
  "status"       TEXT   NOT NULL,
  "output"       TEXT   NOT NULL,
  "passed_count" INT    NOT NULL,
  "failed_count" INT    NOT NULL,
  "created_at"   TIMESTAMPTZ NOT NULL
);

CREATE TABLE "user_progress" (
  "id"              BIGSERIAL PRIMARY KEY,
  "user_id"         BIGINT NOT NULL REFERENCES "user"("id"),
  "exercise_id"     BIGINT NOT NULL REFERENCES "exercise"("id"),
  "status"          TEXT   NOT NULL,
  "first_passed_at" TIMESTAMPTZ,
  "last_submitted_at" TIMESTAMPTZ NOT NULL,
  CONSTRAINT "unique_user_exercise" UNIQUE ("user_id", "exercise_id")
);
```

---

## Indexes

```sql
-- Fetch all submissions for a user on a specific exercise (history view)
CREATE INDEX idx_submission_user_exercise
  ON submission(user_id, exercise_id);

-- Fetch recent submissions for a user across all exercises
CREATE INDEX idx_submission_user_created
  ON submission(user_id, created_at DESC);

-- Fetch all progress rows for a user (progress endpoint)
CREATE INDEX idx_user_progress_user
  ON user_progress(user_id);

-- Fetch ordered exercises within a chapter
CREATE INDEX idx_exercise_chapter_order
  ON exercise(chapter_id, order_in_chapter);

-- Fetch chapters in display order
CREATE INDEX idx_chapter_order
  ON chapter(order_num);
```

The `UniqueGithubId`, `UniqueChapterSlug`, `UniqueExerciseSlug`, and `UniqueUserExercise` constraints each imply an index; no additional index is needed for those columns.

---

## Denormalization Decisions

### UserProgress table

**What:** A `user_progress` row per (user, exercise) pair caches the current completion state, first-pass timestamp, and last-submission timestamp.

**Why:** The progress endpoint (`GET /api/progress`) is called on every page load and returns the user's state across all exercises. Without this table, answering that query requires scanning all submissions, grouping by exercise, and computing the current status — O(submissions) per request. With `user_progress`, it's a single indexed scan.

**How maintained:** Updated transactionally on every submission write. When a submission is inserted, the corresponding `user_progress` row is upserted in the same database transaction. If the submission status is `pass` and `firstPassedAt` is null, it is set to `createdAt`. `status` advances monotonically: `NotStarted` → `Attempted` → `Passed`; a failing submission after a pass does not regress status.

### passedCount / failedCount on Submission

**What:** HSpec output is parsed at submission time and the counts are stored on the row.

**Why:** Avoids re-parsing output text on every read. Output is stored as sanitized text; parsing it again would be fragile.
