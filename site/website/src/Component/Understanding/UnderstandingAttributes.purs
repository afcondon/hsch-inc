-- | UnderstandingAttributes - Now powered by AsciiDoc
-- |
-- | This module demonstrates the hybrid approach: using the DocPage component
-- | to render AsciiDoc-generated HTML while preserving site navigation.
module Component.Understanding.UnderstandingAttributes where

import Prelude

import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Component.Shared.DocPage as DocPage
import Type.Proxy (Proxy(..))

-- | Slots for child components
type Slots = ( docPage :: forall q. H.Slot q Void Unit )

_docPage = Proxy :: Proxy "docPage"

-- | Attributes page component - wraps DocPage with the right input
component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
  }

render :: forall m. MonadAff m => Unit -> H.ComponentHTML Void Slots m
render _ =
  HH.slot_ _docPage unit DocPage.component
    { docPath: "understanding/attributes"
    , pageTitle: "Type-Safe Attributes"
    , quadrant: DocPage.QuadUnderstanding
    }
