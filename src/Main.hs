{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ImportQualifiedPost #-}

module Main where

import ClassyPrelude hiding (Handler)
import Network.Wai (pathInfo)
import Network.Wai qualified as W
import Path
import Path.IO
import Supercede.Auth
import System.FSNotify
import Yesod
import Yesod.Auth
import Yesod.Auth.Simple
import Yesod.AutoReload
import Yesod.Core.Types

{- HLINT ignore "Use newtype instead of data" -}
data App = App
  { getSupercedeAuth :: SupercedeAuth
  }

mkMessage "App" "messages" "en"

mkYesod "App" [parseRoutes|
/ HomeR GET
/ws WebSocketR GET
/auth SupercedeAuthR SupercedeAuth getSupercedeAuth
|]

getHomeR :: Handler Html
getHomeR = do
  now <- liftIO getCurrentTime
  mAuth <- maybeAuthId
  defaultLayout
    [whamlet|
      <p>The time now is: #{tshow now}
      $maybe _ <- mAuth
        <p>
          <a href=@{SupercedeAuthR (AuthR LogoutR)}>Log out
      $nothing
        <p>
          <a href=@{SupercedeAuthR (AuthR loginR)}>Sign in
    |]

getWebSocketR :: Handler ()
getWebSocketR = getAutoReloadRWith $
  liftIO $ do
    sendRefreshVar <- newEmptyMVar -- A variable to block on
    withManager $ \mgr -> do
      let predicate e = case e of
            -- Don't watch removed events, in case the file is rewritten, so we
            -- don't get a 404 when reconecting
            Removed {} -> False
            _ -> not $ any (`isSuffixOf` eventPath e) suffixes
          act _ = putMVar sendRefreshVar ()
      let dirs = ["templates"]
      forM_ dirs $ \d -> do
        ad <- resolveDir' d
        void $ watchTree mgr (fromAbsDir ad) predicate act
      putStrLn "Waiting for a file to change."
      takeMVar sendRefreshVar
  where
  -- Editors make files like this, no need to refresh when they are written.
  suffixes =
    [ ".swp", "~", ".swx",
      "4913" -- https://github.com/neovim/neovim/issues/3460
    ]

instance Yesod App where
  authRoute _ = Just (SupercedeAuthR (AuthR loginR))

  defaultLayout w = do
    p <- widgetToPageContent (w <> autoReloadWidgetFor WebSocketR)
    msgs <- getMessages
    withUrlRenderer [hamlet|
      $newline never
      $doctype 5
      <html>
        <head>
          <title>#{pageTitle p}
          $maybe description <- pageDescription p
            <meta name="description" content="#{description}">
          ^{pageHead p}
        <body>
          $forall (status, msg) <- msgs
              <p class="message #{status}">#{msg}
          ^{pageBody p}
    |]

  isAuthorized _route _isWrite = pure Authorized

instance YesodAuth App where
  type AuthId App = Text
  loginDest _         = HomeR
  logoutDest _        = HomeR
  redirectToReferer _ = True
  authPlugins _       = []
  maybeAuthId = lookupSession "_ID"
  authenticate = pure . Authenticated . credsIdent

instance RenderMessage App FormMessage where
  renderMessage _ _ = defaultFormMessage

instance YesodSubDispatch SupercedeAuth App where
  yesodSubDispatch env req = case traceShowId (pathInfo req) of
    [] -> subHelper Supercede.Auth.getSubHomeR env (Just SubHomeR) req
    ("auth":rest) ->
      yesodSubDispatch
        YesodSubRunnerEnv
          { ysreParentRunner = yesodRunner
          , ysreGetSub = Supercede.Auth.getAuth . getSupercedeAuth
          , ysreToParentRoute = SupercedeAuthR . Supercede.Auth.AuthR
          , ysreParentEnv = ysreParentEnv env
          }
        req { pathInfo = rest }
    _  -> error "not found"

subHelper
  :: ToTypedContent content
  => SubHandlerFor child master content
  -> YesodSubRunnerEnv child master
  -> Maybe (Route child)
  -> W.Application
subHelper (SubHandlerFor f) YesodSubRunnerEnv {..} mroute =
  ysreParentRunner handler ysreParentEnv (ysreToParentRoute <$> mroute)
  where
    handler = fmap toTypedContent $ HandlerFor $ \hd ->
      let rhe = handlerEnv hd
          rhe' = rhe
            { rheRoute = mroute
            , rheChild = ysreGetSub $ yreSite ysreParentEnv
            , rheRouteToMaster = ysreToParentRoute
            }
       in f hd { handlerEnv = rhe' }

makeFoundation :: IO App
makeFoundation = App <$> newSupercedeAuth

main :: IO ()
main = makeFoundation >>= warp 3000

makeApplication :: App -> IO Application
makeApplication foundation = do
  appPlain <- toWaiAppPlain foundation
  return $ defaultMiddlewaresNoLogging appPlain

getApplicationRepl :: IO (Int, App, Application)
getApplicationRepl = do
  foundation <- makeFoundation
  app1       <- makeApplication foundation
  return (3000, foundation, app1)

shutdownApp :: App -> IO ()
shutdownApp _foundation = pure ()
