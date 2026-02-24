-- | STUB: Documentation page component
-- |
-- | TODO: This module was accidentally deleted and needs to be reimplemented.
-- | It provides a reusable documentation page wrapper.
module Component.Shared.DocPage
  ( component
  , Quadrant(..)
  ) where

import Prelude
import Halogen as H
import Halogen.HTML as HH

-- | Quadrant for navigation highlighting
data Quadrant
  = QuadGettingStarted
  | QuadHowTo
  | QuadUnderstanding
  | QuadReference

-- | Input for the doc page
type Input =
  { docPath :: String
  , pageTitle :: String
  , quadrant :: Quadrant
  }

-- | STUB component - just renders a placeholder
component :: forall q o m. H.Component q Input o m
component = H.mkComponent
  { initialState: identity
  , render: \input -> HH.div_ [ HH.text $ "Documentation page: " <> input.pageTitle <> " (stub)" ]
  , eval: H.mkEval H.defaultEval
  }
