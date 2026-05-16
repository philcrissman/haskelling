# Eval Service Design

*Input: ADR-001. Do not write code yet.*

---

## 1. Exercise Object Schema

This schema is the canonical representation used both by the API and for storing curriculum content as git-tracked files.

### Full Schema (internal / file storage)

```
Exercise {
  id                : String          -- URL-safe slug, e.g. "hello-world"
  title             : String          -- Human-readable, e.g. "Hello, World"
  chapter           : String          -- Grouping slug, e.g. "basics", "types", "typeclasses"
  order             : Int             -- Sort position within chapter (1-based)
  learning_objective: String          -- One sentence, e.g. "Define a function that returns a String"
  stub_code         : String          -- Haskell code the user sees and edits
  hidden_test_suite : String          -- HSpec test file; never sent to client or logged
  canonical_solution: String          -- Reference solution; never sent to client or to Judge0
  hints             : [String]        -- Ordered array, 1–5 entries; index 0 is least revealing
}
```

### Client Schema (what the API returns to the browser)

`hidden_test_suite` and `canonical_solution` are always stripped server-side before any response leaves the API. The client never receives them — not in list responses, not in single-exercise responses, not in error payloads.

```
ExerciseClient {
  id                : String
  title             : String
  chapter           : String
  order             : Int
  learning_objective: String
  stub_code         : String
  hints             : [String]
}
```

### Hint constraints

- Minimum 1 hint, maximum 5 hints per exercise.
- Ordered from least to most revealing: index 0 nudges the user toward the concept; the final hint may point directly at the solution approach but should not reproduce the canonical solution.

---

## 2. API Contract

### Exercises

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/exercises` | Required | List all exercises (client schema), grouped by chapter |
| GET | `/api/exercises/:id` | Required | Single exercise (client schema) |

**GET /api/exercises response:**
```
{
  chapters: [
    {
      slug: String,
      title: String,
      exercises: [ExerciseClient]
    }
  ]
}
```

### Submissions

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/submissions` | Required | Submit code for evaluation |
| GET | `/api/submissions?exercise_id=:id` | Required | Submission history for an exercise |

**POST /api/submissions request:**
```
{
  exercise_id : String,   -- must match a known exercise id
  code        : String    -- max 50KB; user-submitted Haskell
}
```

**POST /api/submissions response:**
```
{
  submission_id : String (UUID),
  status        : "pass" | "fail" | "compile_error" | "timeout" | "runtime_error" | "error",
  output        : String,   -- sanitized stdout/stderr from test runner; hints stripped if present
  passed_count  : Int,
  failed_count  : Int,
  evaluated_at  : ISO8601 timestamp
}
```

### Progress

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/progress` | Required | Authenticated user's completion state across all exercises |

**GET /api/progress response:**
```
{
  exercises: [
    {
      exercise_id     : String,
      status          : "not_started" | "attempted" | "passed",
      last_submitted_at: ISO8601 | null
    }
  ]
}
```

### Error codes

| Code | Meaning |
|------|---------|
| 400 | Malformed request body |
| 401 | Not authenticated |
| 404 | Exercise not found |
| 413 | Submitted code exceeds 50KB limit |
| 422 | Validation error (e.g. unknown exercise_id) |
| 429 | Rate limit exceeded |
| 502 | Judge0 unavailable |
| 504 | Judge0 response timeout |

---

## 3. Judge0 Configuration

Since we use managed Judge0 cloud via RapidAPI, this section covers the per-submission parameters we set when calling the Judge0 API, rather than a Dockerfile.

### RapidAPI headers

Every request to Judge0 must include two headers:

```
x-rapidapi-key: <JUDGE0_API_KEY from env>
x-rapidapi-host: judge0-ce.p.rapidapi.com
```

The host header is required by RapidAPI even though it's redundant with the URL. Both are sent from the backend only; never exposed to the client.

### Language

- **Language ID:** 12 (Haskell / GHC) — confirm against current Judge0 language list at integration time, as IDs can change between versions.

### Resource limits per submission

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `cpu_time_limit` | 30s | GHC compilation of a small file typically takes 5–15s cold |
| `wall_time_limit` | 60s | Full wall-clock ceiling including compile + run |
| `memory_limit` | 524288 KB (512MB) | GHC needs ~256MB minimum; 512MB gives headroom |
| `max_file_size` | 1024 KB | Prevent output flooding |
| `number_of_runs` | 1 | Single evaluation per submission |

### Test suite injection

Judge0 supports an `additional_files` parameter: a base64-encoded zip containing supplementary source files. We use this to send user code and the hidden test suite as separate, valid Haskell modules — avoiding the need to concatenate two module declarations into one file, which GHC does not allow.

Submission structure sent to Judge0:

1. **`source_code`**: the hidden test suite (a complete Haskell module, e.g. `module HelloWorldSpec where`, with its own `import HelloWorld` and a `main` that runs the HSpec suite). This file provides the `main` entry point.
2. **`additional_files`**: a base64-encoded zip containing one file — the user's submitted code as `HelloWorld.hs` (filename derived from the exercise slug via PascalCase conversion). GHC compiles both files together.
3. The **canonical solution** is never sent to Judge0.

The filename in the zip must match the module name: `module HelloWorld where` → `HelloWorld.hs`. The slug-to-PascalCase conversion is deterministic and applied uniformly.

**Verification required at BE-03:** Confirm that the Judge0 managed cloud tier supports `additional_files`. This is documented for the self-hosted version; check the cloud API before committing to this approach. Fallback: restructure `hidden_test_suite` to store only the HSpec spec body (no module declaration), and assemble a valid single-module file server-side by parsing and reordering user imports.

All assembly happens in the API server's memory and is never logged or returned to the client.

### Response mapping

Judge0 returns a `status` object. Map to our status values:

| Judge0 status | Our status |
|---------------|------------|
| Accepted | `pass` (if all tests pass) or `fail` (if any test fails) |
| Wrong Answer | `fail` |
| Compilation Error | `compile_error` |
| Time Limit Exceeded | `timeout` |
| Runtime Error | `runtime_error` |
| Internal Error / others | `error` |

Determining `pass` vs `fail` within an Accepted status: parse HSpec's stdout for the summary line (e.g., `3 examples, 0 failures`). If failures == 0, status is `pass`.

---

## 4. Threat Model

### T1: Infinite loop / CPU exhaustion
- **Attack:** Submit `main = main` or similar.
- **Mitigation:** Judge0 `cpu_time_limit` and `wall_time_limit` terminate the process. Response status maps to `timeout`.

### T2: Memory exhaustion
- **Attack:** Submit code that allocates unbounded memory.
- **Mitigation:** Judge0 `memory_limit` (512MB) kills the process. Response maps to `runtime_error`.

### T3: Network access from submitted code
- **Attack:** Submit code using `Network.HTTP` or similar to exfiltrate data or contact external services.
- **Mitigation:** Judge0's sandbox environment disables network access. Verify this for the managed cloud tier at integration time.

### T4: Filesystem access / exfiltration
- **Attack:** Submit code using `readFile`, `writeFile`, or shell commands to read or write the host filesystem.
- **Mitigation:** Judge0 sandboxes filesystem access. Submitted code cannot reach the API server's filesystem.

### T5: Extracting the hidden test suite
- **Attack:** Submit code that prints arbitrary strings or inspects the compiled binary to recover the test suite.
- **Mitigation:** Test suite is injected server-side; the combined source is not returned in any response. Sanitize Judge0's stdout before returning: strip any lines that reproduce test file contents verbatim. Do not return raw compiler output from the hidden portion of the source.

### T6: Extracting the canonical solution
- **Attack:** Any attempt to recover the reference solution.
- **Mitigation:** Canonical solution is stored only in the exercise files and is never sent to Judge0, never included in any API response, and never logged.

### T7: Rate limit abuse / cost amplification
- **Attack:** Script rapid submissions to exhaust the Judge0 execution quota or drive up costs.
- **Mitigation:** Per-user rate limit on `POST /api/submissions` (e.g., 10 requests/minute per user). Server-side code size limit (50KB) before forwarding to Judge0. Alert if monthly Judge0 execution count approaches tier limit.

### T8: Oversized submissions
- **Attack:** Submit a 10MB file to cause memory pressure or slow compilation.
- **Mitigation:** Enforce 50KB max on `code` field; return 413 before touching Judge0.

### T9: Judge0 API key exposure
- **Attack:** Recover the Judge0 API key from responses, logs, or error messages.
- **Mitigation:** Key stored as an environment secret; never returned in any response; excluded from structured logging.

### T10: Malicious exercise content (supply chain)
- **Attack:** A contributed exercise contains stub code or test code designed to compromise users or the system.
- **Mitigation:** Exercise content is authored via git PR and reviewed before merge. Stub code is served as plain text to the client, not executed server-side. Hidden test suite runs only inside the Judge0 sandbox.

---

## 5. Testing Plan

### Unit tests (Haskell, no Judge0 dependency)

- Code size validation: reject at ≥ 50KB, accept below
- Request body parsing: valid and invalid shapes
- Test suite injection: verify combined source has correct module structure
- Judge0 response mapping: each status code maps to the correct internal status
- HSpec output parsing: correctly identify pass (0 failures) vs. fail (N failures)
- Canonical solution and hidden test suite are absent from all serialized responses
- Rate limit counter increments and resets correctly

### Integration tests (against Judge0 staging / test account)

- **Happy path:** Valid Haskell, all tests pass → `pass`
- **Partial pass:** Valid Haskell, some tests fail → `fail` with correct counts
- **Compile error:** Syntax error in submitted code → `compile_error` with sanitized output
- **Timeout:** Infinite loop → `timeout`
- **Memory limit:** Unbounded allocation → `runtime_error`
- **Oversized input:** Rejected before reaching Judge0 → 413
- **Rate limit:** Eleventh request in a minute → 429, not forwarded to Judge0

### Security tests

- Submit code that attempts to print the test suite source: verify test suite text does not appear in response output
- Submit code using `unsafePerformIO` and `readFile`: verify no filesystem leakage
- Submit code that imports `Network.HTTP` or similar: verify network is blocked
- Verify canonical solution string does not appear in any response across all test fixtures

### Failure mode tests

- Judge0 returns 503: API returns 502, no crash
- Judge0 response exceeds wall_time_limit: API returns 504
- Judge0 returns unexpected status ID: API maps to `error`, logs the raw value, does not surface it to client
