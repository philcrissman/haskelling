{-# LANGUAGE ScopedTypeVariables #-}

module Auth
  ( AuthEnv
  , ClerkUser (..)
  , newAuthEnv
  , parseJwksUrl
  , validateToken
  , fetchClerkUser
  ) where

import Control.Exception (SomeException, try)
import Control.Monad.Except (runExceptT)
import Crypto.JWT
import Data.Aeson (FromJSON (..), Value (..), decode, encode, eitherDecode, withObject, (.:), (.:?))
import Data.Aeson.Types (parseMaybe)
import Data.ByteString.Base64.URL qualified as B64URL
import Data.ByteString.Lazy qualified as BSL
import Data.IORef
import Data.Maybe (listToMaybe)
import Data.Time (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)

-- | Holds JWKS URL, expected token issuer, Clerk secret key, cached JWK set
-- (with the time it was fetched), and HTTP manager.
data AuthEnv = AuthEnv
  { authJwksUrl   :: Text
  , authIssuer    :: Text
  , authSecretKey :: Text
  , authJwkCache  :: IORef (Maybe (JWKSet, UTCTime))
  , authManager   :: Manager
  }

-- | Proactively re-fetch the JWK set once it is older than this.
jwksTtl :: NominalDiffTime
jwksTtl = 3600  -- 1 hour

-- | Lower bound between forced re-fetches triggered by verification failures.
-- Bounds JWKS traffic when bad tokens arrive in bursts, while still recovering
-- from a Clerk key rotation within this window.
jwksMinRefetch :: NominalDiffTime
jwksMinRefetch = 60  -- 1 minute

-- | User info fetched from Clerk's management API after first sign-in.
data ClerkUser = ClerkUser
  { clerkUserUsername :: Text
  , clerkUserEmail    :: Maybe Text
  , clerkUserAvatar   :: Maybe Text
  }

-- Internal types for Clerk API JSON parsing

newtype EmailEntry = EmailEntry { emailEntryAddress :: Text }

instance FromJSON EmailEntry where
  parseJSON = withObject "EmailEntry" $ \o ->
    EmailEntry <$> o .: "email_address"

data ExternalAccount = ExternalAccount
  { extProvider :: Text
  , extUsername :: Maybe Text
  }

instance FromJSON ExternalAccount where
  parseJSON = withObject "ExternalAccount" $ \o ->
    ExternalAccount
      <$> o .:  "provider"
      <*> o .:? "username"

data ClerkUserRaw = ClerkUserRaw
  { rawId       :: Text
  , rawUsername :: Maybe Text
  , rawEmails   :: [EmailEntry]
  , rawImage    :: Maybe Text
  , rawExtAccts :: [ExternalAccount]
  }

instance FromJSON ClerkUserRaw where
  parseJSON = withObject "ClerkUserRaw" $ \o ->
    ClerkUserRaw
      <$> o .:  "id"
      <*> o .:? "username"
      <*> o .:  "email_addresses"
      <*> o .:? "image_url"
      <*> o .:  "external_accounts"

toClerkUser :: ClerkUserRaw -> ClerkUser
toClerkUser raw = ClerkUser
  { clerkUserUsername =
      case rawUsername raw of
        Just u  -> u
        Nothing ->
          case filter ((== "github") . extProvider) (rawExtAccts raw) of
            (gh:_) -> maybe (rawId raw) id (extUsername gh)
            []     -> rawId raw
  , clerkUserEmail  = emailEntryAddress <$> listToMaybe (rawEmails raw)
  , clerkUserAvatar = rawImage raw
  }

-- | Derive the Clerk JWKS URL from a publishable key.
-- Format: pk_{env}_{base64url(domain + "$")}
parseJwksUrl :: Text -> Either Text Text
parseJwksUrl pk =
  case T.splitOn "_" pk of
    (_:_:rest) ->
      let b64    = T.intercalate "_" rest
          raw    = B64URL.decodeLenient (TE.encodeUtf8 b64)
          domain = T.dropWhileEnd (== '$') (TE.decodeUtf8 raw)
      in Right ("https://" <> domain <> "/.well-known/jwks.json")
    _ -> Left "Invalid publishable key format (expected pk_{env}_{base64})"

newAuthEnv :: Text -> Text -> IO AuthEnv
newAuthEnv jwksUrl secretKey = do
  mgr <- newManager tlsManagerSettings
  ref <- newIORef Nothing
  -- Clerk's token issuer is the instance domain without the JWKS path,
  -- e.g. https://example.clerk.accounts.dev
  let issuer = maybe jwksUrl id (T.stripSuffix "/.well-known/jwks.json" jwksUrl)
  pure AuthEnv
    { authJwksUrl   = jwksUrl
    , authIssuer    = issuer
    , authSecretKey = secretKey
    , authJwkCache  = ref
    , authManager   = mgr
    }

-- | Return the JWK set, re-fetching when absent, stale (older than 'jwksTtl'),
-- or when @force@ is set. On a fetch failure we fall back to the stale cached
-- set if we have one, so a transient network blip does not break all auth.
getJwks :: AuthEnv -> Bool -> IO (Either Text JWKSet)
getJwks env force = do
  now    <- getCurrentTime
  cached <- readIORef (authJwkCache env)
  let usable = case cached of
        Just (jwks, fetchedAt)
          | not force && diffUTCTime now fetchedAt < jwksTtl -> Just jwks
        _ -> Nothing
  case usable of
    Just jwks -> pure (Right jwks)
    Nothing   -> do
      result <- fetchJwks (authManager env) (authJwksUrl env)
      case result of
        Right jwks -> do
          writeIORef (authJwkCache env) (Just (jwks, now))
          pure (Right jwks)
        Left err -> pure $ case cached of
          Just (jwks, _) -> Right jwks
          Nothing        -> Left err

fetchJwks :: Manager -> Text -> IO (Either Text JWKSet)
fetchJwks mgr url = do
  result <- try $ do
    req  <- parseRequest (T.unpack url)
    resp <- httpLbs req mgr
    pure (responseBody resp)
  case (result :: Either SomeException BSL.ByteString) of
    Left  err  -> pure (Left (T.pack (show err)))
    Right body -> pure $ case eitherDecode body of
      Left  err  -> Left (T.pack err)
      Right jwks -> Right jwks

-- | Validate a Bearer token. Returns the Clerk user ID on success.
--
-- If verification fails with the cached keys we re-fetch the JWKS once (bounded
-- by 'jwksMinRefetch') and retry, so a Clerk signing-key rotation recovers
-- automatically instead of breaking every login until the next deploy.
validateToken :: AuthEnv -> Text -> IO (Either Text Text)
validateToken env token = do
  r1 <- attempt False
  case r1 of
    Right sub -> pure (Right sub)
    Left  e1  -> do
      now    <- getCurrentTime
      cached <- readIORef (authJwkCache env)
      let stale = case cached of
            Just (_, fetchedAt) -> diffUTCTime now fetchedAt >= jwksMinRefetch
            Nothing             -> True
      if stale then attempt True else pure (Left e1)
  where
    attempt force = do
      ejwks <- getJwks env force
      case ejwks of
        Left err   -> pure (Left ("JWKS error: " <> err))
        Right jwks -> do
          result <- runExceptT (verifyTok jwks) :: IO (Either JWTError ClaimsSet)
          pure $ case result of
            Left  err    -> Left (T.pack (show err))
            Right claims -> checkClaims env claims
    verifyTok keys = do
      jwt <- decodeCompact (BSL.fromStrict (TE.encodeUtf8 token))
      verifyClaims (defaultJWTValidationSettings (const True)) keys jwt

-- Extract the "sub" claim and confirm the "iss" claim matches the expected
-- Clerk issuer, so a validly-signed token from a different instance is rejected.
-- Uses an aeson roundtrip (avoids a lens dependency on StringOrURI).
checkClaims :: AuthEnv -> ClaimsSet -> Either Text Text
checkClaims env claims =
  case decode (encode claims) :: Maybe Value of
    Just (Object o) -> do
      sub <- note "missing sub claim in JWT" (parseMaybe (.: "sub") o)
      iss <- note "missing iss claim in JWT" (parseMaybe (.: "iss") o)
      if iss == authIssuer env
        then Right sub
        else Left "unexpected token issuer"
    _ -> Left "could not parse JWT claims"
  where
    note msg = maybe (Left msg) Right

-- | Fetch user details from Clerk's management API.
fetchClerkUser :: AuthEnv -> Text -> IO (Either Text ClerkUser)
fetchClerkUser env clerkId = do
  let url = "https://api.clerk.com/v1/users/" <> T.unpack clerkId
  result <- try $ do
    req <- parseRequest url
    let req' = req
          { requestHeaders =
              [("Authorization", "Bearer " <> TE.encodeUtf8 (authSecretKey env))]
          }
    resp <- httpLbs req' (authManager env)
    pure (responseBody resp)
  case (result :: Either SomeException BSL.ByteString) of
    Left  err  -> pure (Left (T.pack (show err)))
    Right body -> pure $ case eitherDecode body of
      Left  err -> Left (T.pack err)
      Right raw -> Right (toClerkUser raw)
