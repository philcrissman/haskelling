module Main where

import Network.Wai.Handler.Warp (run)
import Server (app)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

main :: IO ()
main = do
  portStr <- lookupEnv "PORT"
  let port = case portStr >>= readMaybe of
        Just p -> p
        Nothing -> 8080
  putStrLn $ "haskelling: listening on port " <> show port
  run port app
