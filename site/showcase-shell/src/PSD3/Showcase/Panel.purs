module PSD3.Showcase.Panel
  ( panel
  , Output(..)
  , Query(..)
  , Slot
  ) where

import Prelude

import Data.Const (Const)
import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import PSD3.Showcase.Types (PanelConfig, PanelPosition(..), panelPositionToClass)
import Type.Proxy (Proxy(..))

-- | Panel slot type for parent components
type Slot = H.Slot Query Output

-- | Panel queries (for parent to control)
data Query a
  = SetOpen Boolean a
  | Toggle a
  | IsOpen (Boolean -> a)

-- | Panel output events
data Output
  = Toggled Boolean  -- Emitted when panel open state changes

-- | Internal state
type State =
  { config :: PanelConfig
  , isOpen :: Boolean
  }

-- | Internal actions
data Action
  = Initialize
  | TogglePanel
  | Receive PanelConfig

-- | Slot for panel content
type Slots = ( content :: H.Slot (Const Void) Void Unit )

_content :: Proxy "content"
_content = Proxy

-- | The panel component
panel
  :: forall m
   . MonadAff m
  => H.Component Query PanelConfig Output m
panel = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleAction = handleAction
      , handleQuery = handleQuery
      , receive = Just <<< Receive
      , initialize = Just Initialize
      }
  }

initialState :: PanelConfig -> State
initialState config =
  { config
  , isOpen: config.initialOpen
  }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  HH.div
    [ HP.classes $ panelClasses state
    , HP.id state.config.id
    , HP.style $ panelStyle state
    ]
    [ -- Toggle button (if toggleable)
      if state.config.toggleable
        then renderToggle state
        else HH.text ""
    -- Panel content container
    , HH.div
        [ HP.classes [ HH.ClassName "showcase-panel-content" ] ]
        [ HH.slot_ _content unit placeholderComponent unit ]
    ]

-- | Placeholder component for content slot
placeholderComponent :: forall m. H.Component (Const Void) Unit Void m
placeholderComponent = H.mkComponent
  { initialState: identity
  , render: \_ -> HH.text ""
  , eval: H.mkEval H.defaultEval
  }

renderToggle :: forall m. State -> H.ComponentHTML Action Slots m
renderToggle state =
  HH.button
    [ HE.onClick \_ -> TogglePanel
    , HP.classes [ HH.ClassName "showcase-panel-toggle" ]
    ]
    [ HH.text $ toggleIcon state ]

toggleIcon :: State -> String
toggleIcon state = case state.config.position, state.isOpen of
  Left, true -> "◀"
  Left, false -> "▶"
  Right, true -> "▶"
  Right, false -> "◀"
  Bottom, true -> "▼"
  Bottom, false -> "▲"
  _, true -> "−"
  _, false -> "+"

panelClasses :: State -> Array HH.ClassName
panelClasses state =
  [ HH.ClassName "showcase-panel"
  , HH.ClassName $ "showcase-panel--" <> panelPositionToClass state.config.position
  ] <> if state.isOpen
        then [ HH.ClassName "showcase-panel--open" ]
        else [ HH.ClassName "showcase-panel--closed" ]

panelStyle :: State -> String
panelStyle state =
  let
    width = case state.config.width of
      Just w -> "width: " <> w <> ";"
      Nothing -> ""
    height = case state.config.height of
      Just h -> "height: " <> h <> ";"
      Nothing -> ""
  in
    width <> height

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> pure unit

  TogglePanel -> do
    state <- H.get
    let newOpen = not state.isOpen
    H.modify_ _ { isOpen = newOpen }
    H.raise (Toggled newOpen)

  Receive config -> do
    H.modify_ _ { config = config }

handleQuery :: forall m a. Query a -> H.HalogenM State Action Slots Output m (Maybe a)
handleQuery = case _ of
  SetOpen open reply -> do
    state <- H.get
    when (state.isOpen /= open) do
      H.modify_ _ { isOpen = open }
      H.raise (Toggled open)
    pure (Just reply)

  Toggle reply -> do
    state <- H.get
    let newOpen = not state.isOpen
    H.modify_ _ { isOpen = newOpen }
    H.raise (Toggled newOpen)
    pure (Just reply)

  IsOpen reply -> do
    state <- H.get
    pure (Just (reply state.isOpen))
