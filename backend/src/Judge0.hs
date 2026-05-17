module Judge0
  ( Judge0Config (..)
  , SubmissionResult (..)
  , submitAndWait
  ) where

import Codec.Archive.Zip (addEntryToArchive, emptyArchive, fromArchive, toEntry)
import Control.Concurrent (threadDelay)
import Data.Aeson (FromJSON (..), eitherDecode, encode, object, withObject, (.:), (.:?), (.=))
import Data.Aeson.Types (parseMaybe)
import Data.ByteString.Base64 qualified as B64
import Data.ByteString.Lazy qualified as BSL
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Schema (SubmissionStatus (..))

-- Configuration

data Judge0Config = Judge0Config
  { judge0ApiUrl  :: Text
  , judge0ApiKey  :: Text
  , judge0ApiHost :: Text
  , judge0Mock    :: Bool
  }

-- Internal Judge0 response types

newtype Judge0Status = Judge0Status
  { statusId :: Int
  }

instance FromJSON Judge0Status where
  parseJSON = withObject "Judge0Status" $ \o ->
    Judge0Status <$> o .: "id"

data Judge0Response = Judge0Response
  { j0Status        :: Judge0Status
  , j0Stdout        :: Maybe Text
  , j0CompileOutput :: Maybe Text
  }

instance FromJSON Judge0Response where
  parseJSON = withObject "Judge0Response" $ \o ->
    Judge0Response
      <$> o .:  "status"
      <*> (fmap decodeB64Text <$> o .:? "stdout")
      <*> (fmap decodeB64Text <$> o .:? "compile_output")

decodeB64Text :: Text -> Text
decodeB64Text t =
  case B64.decode (TE.encodeUtf8 t) of
    Left _   -> t
    Right bs -> TE.decodeUtf8 bs

-- Public result type

data SubmissionResult = SubmissionResult
  { srStatus      :: SubmissionStatus
  , srOutput      :: Text
  , srPassedCount :: Int
  , srFailedCount :: Int
  }

-- Mock response: returns a passing result without calling Judge0

mockResult :: SubmissionResult
mockResult = SubmissionResult
  { srStatus      = StatusPass
  , srOutput      = "1 examples, 0 failures"
  , srPassedCount = 1
  , srFailedCount = 0
  }

-- Map Judge0 status ID to our SubmissionStatus, using stdout to distinguish
-- NZEC (our test runner called exitFailure) from a real runtime error.

interpretResult :: Judge0Response -> SubmissionResult
interpretResult resp =
  let sid    = statusId (j0Status resp)
      stdout = maybe "" id (j0Stdout resp)
      (ourStatus, out, passed, failed) = case sid of
        3 ->
          -- Accepted: all tests passed
          let (p, f) = parseCounts stdout
          in  (StatusPass, stdout, p, f)
        6 ->
          -- Compilation Error
          ( StatusCompileError
          , sanitizeCompileOutput (j0CompileOutput resp)
          , 0, 0
          )
        5 ->
          -- Time Limit Exceeded
          (StatusTimeout, "Time limit exceeded.", 0, 0)
        11 ->
          -- Runtime Error (NZEC): check whether it's our test runner exiting
          if hasSummaryLine stdout
            then
              let (p, f) = parseCounts stdout
              in  (StatusFail, stdout, p, f)
            else
              (StatusRuntimeError, stdout, 0, 0)
        _ ->
          -- Anything else (memory limit, internal error, etc.)
          (StatusError, "An unexpected error occurred.", 0, 0)
  in SubmissionResult
       { srStatus      = ourStatus
       , srOutput      = out
       , srPassedCount = passed
       , srFailedCount = failed
       }

-- "N examples, M failures" appears in our test runner's final line.
hasSummaryLine :: Text -> Bool
hasSummaryLine t = any ("examples," `T.isInfixOf`) (T.lines t)

parseCounts :: Text -> (Int, Int)
parseCounts t =
  case filter ("examples," `T.isInfixOf`) (T.lines t) of
    [] -> (0, 0)
    (l:_) ->
      let ws = T.words l
      in case ws of
           (n : _ : _ : f : _) ->
             (readInt n, readInt f)
           _ -> (0, 0)
  where
    readInt s = case reads (T.unpack s) of
      [(i, "")] -> i
      _         -> 0

sanitizeCompileOutput :: Maybe Text -> Text
sanitizeCompileOutput Nothing  = "Compilation failed."
sanitizeCompileOutput (Just t) =
  -- Strip lines that reference the hidden test module
  T.unlines
    . filter (not . T.isInfixOf "Main.hs")
    . T.lines
    $ t

-- HTTP submission

-- Encode text as UTF-8 then base64 (for source_code / stdin fields)
encodeSource :: Text -> Text
encodeSource = TE.decodeUtf8 . B64.encode . TE.encodeUtf8

-- Build a base64-encoded zip containing the user's solution as <ModuleName>.hs.
-- Judge0 extracts this alongside the test runner so the import resolves.
makeAdditionalFiles :: Text -> Text -> Text
makeAdditionalFiles exerciseSlug userCode =
  let moduleName = T.concat . map T.toTitle . T.splitOn "-" $ exerciseSlug
      fileName   = T.unpack moduleName <> ".hs"
      entry      = toEntry fileName 0 (BSL.fromStrict (TE.encodeUtf8 userCode))
      archive    = addEntryToArchive entry emptyArchive
  in TE.decodeUtf8 . B64.encode . BSL.toStrict . fromArchive $ archive

submitAndWait :: Judge0Config -> Text -> Text -> Text -> IO SubmissionResult
submitAndWait cfg exerciseSlug userCode hiddenTests
  | judge0Mock cfg = pure mockResult
  | otherwise = do
      mgr <- newManager tlsManagerSettings
      token <- submitBatch cfg mgr exerciseSlug userCode hiddenTests
      pollResult cfg mgr token

-- source_code = the test runner (module Main); additional_files = zip of the
-- user's solution so the import in the test runner resolves.
submitBatch :: Judge0Config -> Manager -> Text -> Text -> Text -> IO Text
submitBatch cfg mgr exerciseSlug userCode hiddenTests = do
  let additionalFiles = makeAdditionalFiles exerciseSlug userCode
      payload         = encode $ object
        [ "language_id"        .= (61 :: Int)  -- GHC 8.8.1
        , "source_code"        .= encodeSource hiddenTests
        , "additional_files"   .= additionalFiles
        , "stdin"              .= encodeSource ""
        , "cpu_time_limit"     .= (20 :: Int)
        , "wall_time_limit"    .= (30 :: Int)
        , "memory_limit"       .= (512000 :: Int)
        ]
      url         = T.unpack (judge0ApiUrl cfg) <> "/submissions?base64_encoded=true&wait=false"
  initReq <- parseRequest url
  let req = initReq
        { method      = "POST"
        , requestBody = RequestBodyLBS payload
        , requestHeaders =
            [ ("Content-Type",    "application/json")
            , ("x-rapidapi-key",  TE.encodeUtf8 (judge0ApiKey  cfg))
            , ("x-rapidapi-host", TE.encodeUtf8 (judge0ApiHost cfg))
            ]
        }
  resp <- httpLbs req mgr
  case eitherDecode (responseBody resp) of
    Left err  -> fail $ "Judge0 submit parse error: " <> err
    Right obj -> case parseMaybe (.: "token") obj of
      Nothing    -> fail "Judge0 submit: no token in response"
      Just token -> pure token

-- Poll GET /submissions/:token until status is not queued/processing
pollResult :: Judge0Config -> Manager -> Text -> IO SubmissionResult
pollResult cfg mgr token = go (0 :: Int)
  where
    go attempts
      | attempts >= 15 = pure $ SubmissionResult StatusTimeout "Timed out waiting for result." 0 0
      | otherwise = do
          threadDelay 2_000_000  -- 2 seconds
          let url = T.unpack (judge0ApiUrl cfg) <> "/submissions/" <> T.unpack token
                 <> "?base64_encoded=true&fields=status,stdout,stderr,compile_output,message"
          initReq <- parseRequest url
          let req = initReq
                { requestHeaders =
                    [ ("x-rapidapi-key",  TE.encodeUtf8 (judge0ApiKey  cfg))
                    , ("x-rapidapi-host", TE.encodeUtf8 (judge0ApiHost cfg))
                    ]
                }
          resp <- httpLbs req mgr
          case eitherDecode (responseBody resp) of
            Left err -> fail $ "Judge0 poll parse error: " <> err
            Right j0resp ->
              let sid = statusId (j0Status j0resp)
              in if sid <= 2  -- 1 = In Queue, 2 = Processing
                   then go (attempts + 1)
                   else pure (interpretResult j0resp)
