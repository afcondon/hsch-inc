-- | Entry point for Type Explorer
module TypeExplorer.Main where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.DOM.ParentNode (QuerySelector(..))
import TypeExplorer.App as App

main :: Effect Unit
main = HA.runHalogenAff do
  -- Wait for body
  body <- HA.awaitBody

  -- Try to mount to #app, fallback to body
  maybeApp <- HA.selectElement (QuerySelector "#app")
  let mountPoint = case maybeApp of
        Just el -> el
        Nothing -> body

  -- Run the UI
  _ <- runUI App.component unit mountPoint
  pure unit
