{-# LANGUAGE DataKinds #-}

module Server where

import API
import Servant

healthHandler :: Handler HealthResponse
healthHandler = return $ HealthResponse {status = "ok"}

server :: Server API
server = healthHandler

app :: Application
app = serve (Proxy :: Proxy API) server
