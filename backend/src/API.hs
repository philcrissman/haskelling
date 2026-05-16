{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module API where

import Data.Aeson (ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Servant

newtype HealthResponse = HealthResponse {status :: Text}
  deriving (Generic)

instance ToJSON HealthResponse

type HealthAPI = "health" :> Get '[JSON] HealthResponse

type API = HealthAPI
