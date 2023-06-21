{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Supercede.Auth
  ( module Supercede.Auth.Data
  , module Supercede.Auth
  , maybeAuthId
  , Auth
  , getAuth
  ) where

import ClassyPrelude hiding (Handler)
import StaticFiles
import Yesod.Core.Types
--import Text.Cassius.Ordered
import Supercede.Auth.Data
import Text.Julius
import Text.Lucius.Ordered
import Yesod
import Yesod.Auth
import Yesod.Auth.Simple

{-
layout ::
     Yesod master
  => WidgetFor SupercedeAuth ()
  -> SubHandlerFor SupercedeAuth master Html
layout widget = defaultLayout $ do
  addStylesheet $ StaticR css_normalize_css
  addStylesheet $ StaticR css_skeleton_css
  addStylesheet $ StaticR css_animate_css
  addStylesheet $ StaticR css_buttons_css
  addScript $ StaticR js_jquery_js
  toWidget $(luciusFile "templates/layout.lucius")
  widget
-}

loginTemplate ::
     --RenderMessage SupercedeAuth SupercedeAuthMessage
     (Route Auth -> Route SupercedeAuth)
  -> Maybe Text
  -> Maybe Text
  -> WidgetFor SupercedeAuth ()
loginTemplate toParent mErr mEmail = do
  req <- getRequest
  --mr <- getMessageRender
  let passwordId = "password" :: Text
  passwordRowId <- newIdent
  toggleSsoId <- newIdent
  $(whamletFile "templates/login.hamlet")
  toWidget $(luciusFile "templates/login.lucius")
  toWidget $(juliusFile "templates/login.julius")

getSubHomeR :: Yesod master => SubHandlerFor SupercedeAuth master Html
getSubHomeR = liftHandler $ do
  -- toParent <- getRouteToParent
  defaultLayout
    [whamlet|
      <p>Welcome to the subsite!
      $#<p><a href=@{toParent (AuthR loginR)}>Sign in.</a>
    |]

instance YesodAuth SupercedeAuth where
  type AuthId SupercedeAuth = Text
  loginDest _         = SubHomeR
  logoutDest _        = AuthR loginR
  redirectToReferer _ = True
  authPlugins _       = [ authSimple ]
  maybeAuthId = lookupSession "_ID"
  authenticate = pure . Authenticated . credsIdent
  --authLayout = liftHandler . layout

instance YesodAuthSimple SupercedeAuth where
  type AuthSimpleId SupercedeAuth = Text
  afterPasswordRoute _ = SubHomeR

  getUserId email
    | valid email = pure $ Just "1"
    | otherwise   = pure Nothing
    where valid = (Email "test@supercede.com" ==)

  getUserPassword _userId = hashPassword "strongpass"

  onRegisterSuccess = redirect SubHomeR
  insertUser _ _ = pure Nothing
  updateUserPassword _ _ = pure ()
  matchRegistrationToken _ = pure Nothing
  matchPasswordToken _ = pure Nothing

  loginTemplate = Supercede.Auth.loginTemplate
