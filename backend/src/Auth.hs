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
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)

-- | Holds JWKS URL, Clerk secret key, cached JWK set, and HTTP manager.
data AuthEnv = AuthEnv
  { authJwksUrl   :: Text
  , authSecretKey :: Text
  , authJwkCache  :: IORef (Maybe JWKSet)
  , authManager   :: Manager
  }

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
  pure AuthEnv
    { authJwksUrl   = jwksUrl
    , authSecretKey = secretKey
    , authJwkCache  = ref
    , authManager   = mgr
    }

getJwks :: AuthEnv -> IO (Either Text JWKSet)
getJwks env = do
  cached <- readIORef (authJwkCache env)
  case cached of
    Just jwks -> pure (Right jwks)
    Nothing   -> do
      result <- fetchJwks (authManager env) (authJwksUrl env)
      case result of
        Right jwks -> writeIORef (authJwkCache env) (Just jwks)
        _          -> pure ()
      pure result

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
validateToken :: AuthEnv -> Text -> IO (Either Text Text)
validateToken env token = do
  ejwks <- getJwks env
  case ejwks of
    Left err   -> pure (Left ("JWKS error: " <> err))
    Right jwks -> do
      result <- runExceptT (verify jwks) :: IO (Either JWTError ClaimsSet)
      pure $ case result of
        Left  err    -> Left (T.pack (show err))
        Right claims -> extractSub claims
  where
    verify jwks = do
      jwt <- decodeCompact (BSL.fromStrict (TE.encodeUtf8 token))
      verifyClaims (defaultJWTValidationSettings (const True)) jwks jwt

-- Extract the "sub" claim as Text using aeson roundtrip (avoids lens dependency on StringOrURI).
extractSub :: ClaimsSet -> Either Text Text
extractSub claims =
  case parseMaybe (withObject "ClaimsSet" (.: "sub")) =<< (decode (encode claims) :: Maybe Value) of
    Just t  -> Right t
    Nothing -> Left "missing sub claim in JWT"

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
