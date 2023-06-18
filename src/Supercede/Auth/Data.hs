{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Supercede.Auth.Data where

import ClassyPrelude
import Yesod
import Yesod.Auth
import Yesod.Static

{- HLINT ignore "Use newtype instead of data" -}
data SupercedeAuth = SupercedeAuth
  { getStatic :: Static
  }

--mkMessage "SupercedeAuth" "messages" "en"

mkYesodSubData "SupercedeAuth" [parseRoutes|
/ SubHomeR GET
/auth AuthR Auth getAuth
/static StaticR Static getStatic
|]

newSupercedeAuth :: MonadIO m => m SupercedeAuth
newSupercedeAuth = SupercedeAuth <$> liftIO (static "static")

instance Yesod SupercedeAuth

instance RenderMessage SupercedeAuth FormMessage where
  renderMessage _ _ = defaultFormMessage
