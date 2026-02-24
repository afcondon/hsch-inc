module PSD3.Showcase.Shell
  ( showcaseShell
  , ShellSlots
  , ShellInput
  , ShellOutput(..)
  , ShellQuery(..)
  , PanelState
  ) where

import Prelude

import Data.Const (Const)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Tuple (Tuple(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import PSD3.Showcase.Types (PanelConfig, PanelPosition(..), ShellConfig, ZoomState, panelPositionToClass)
import Type.Proxy (Proxy(..))

-- | Slots exposed by the shell for parent to fill
type ShellSlots =
  ( header :: H.Slot (Const Void) Void Unit
  , svg :: H.Slot (Const Void) Void Unit
  , panel :: H.Slot (Const Void) Void String  -- keyed by panel ID
  )

-- | Proxies for slot access
_header :: Proxy "header"
_header = Proxy

_svg :: Proxy "svg"
_svg = Proxy

_panel :: Proxy "panel"
_panel = Proxy

-- | Input to the shell component
type ShellInput =
  { config :: ShellConfig
  , panels :: Array PanelConfig
  , initialZoom :: Maybe ZoomState
  }

-- | Output events from the shell
data ShellOutput
  = ZoomChanged ZoomState
  | PanelToggled String Boolean  -- panel id, new open state

-- | Queries the parent can send to the shell
data ShellQuery a
  = SetPanelOpen String Boolean a
  | TogglePanel String a
  | GetZoom (ZoomState -> a)
  | SetZoom ZoomState a

-- | Panel open/closed state
type PanelState = Map String Boolean

-- | Internal state
type State =
  { config :: ShellConfig
  , panels :: Array PanelConfig
  , panelStates :: PanelState
  , zoom :: ZoomState
  }

-- | Internal actions
data Action
  = Initialize
  | HandleTogglePanel String
  | HandleZoomChange ZoomState
  | Receive ShellInput

-- | The showcase shell component
showcaseShell
  :: forall m
   . MonadAff m
  => H.Component ShellQuery ShellInput ShellOutput m
showcaseShell = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleAction = handleAction
      , handleQuery = handleQuery
      , receive = Just <<< Receive
      , initialize = Just Initialize
      }
  }

initialState :: ShellInput -> State
initialState input =
  { config: input.config
  , panels: input.panels
  , panelStates: Map.fromFoldable $
      map (\p -> Tuple p.id p.initialOpen) input.panels
  , zoom: fromMaybe identityZoom input.initialZoom
  }
  where
    identityZoom = { k: 1.0, x: 0.0, y: 0.0 }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action ShellSlots m
render state =
  HH.div
    [ HP.classes [ HH.ClassName "showcase-shell" ]
    , HP.style $ "--showcase-header-height: " <> state.config.headerHeight <> ";"
    ]
    [ -- Header (fixed at top)
      HH.header
        [ HP.classes [ HH.ClassName "showcase-header" ] ]
        [ HH.slot_ _header unit placeholderComponent unit ]

    -- Main content area
    , HH.div
        [ HP.classes [ HH.ClassName "showcase-main" ] ]
        [ -- SVG layer (full viewport, zoomable)
          HH.div
            [ HP.classes [ HH.ClassName "showcase-svg-layer" ]
            , HP.id "showcase-svg-container"
            ]
            [ HH.slot_ _svg unit placeholderComponent unit ]

        -- Panels
        , HH.div
            [ HP.classes [ HH.ClassName "showcase-panels" ] ]
            (map (renderPanel state) state.panels)
        ]
    ]

renderPanel :: forall m. MonadAff m => State -> PanelConfig -> H.ComponentHTML Action ShellSlots m
renderPanel state panelConfig =
  let
    isOpen = fromMaybe panelConfig.initialOpen $
      Map.lookup panelConfig.id state.panelStates
    posClass = "showcase-panel--" <> panelPositionToClass panelConfig.position
    openClass = if isOpen then "showcase-panel--open" else "showcase-panel--closed"
  in
    HH.div
      [ HP.classes
          [ HH.ClassName "showcase-panel"
          , HH.ClassName posClass
          , HH.ClassName openClass
          ]
      , HP.id panelConfig.id
      , HP.style $ panelStyle panelConfig
      ]
      [ -- Toggle button (if toggleable)
        if panelConfig.toggleable
          then HH.button
            [ HE.onClick \_ -> HandleTogglePanel panelConfig.id
            , HP.classes [ HH.ClassName "showcase-panel-toggle" ]
            ]
            [ HH.text $ toggleIcon panelConfig.position isOpen ]
          else HH.text ""
      -- Panel content
      , HH.div
          [ HP.classes [ HH.ClassName "showcase-panel-content" ] ]
          [ HH.slot_ _panel panelConfig.id placeholderComponent unit ]
      ]

toggleIcon :: PanelPosition -> Boolean -> String
toggleIcon position isOpen = case position, isOpen of
  Left, true -> "◀"
  Left, false -> "▶"
  Right, true -> "▶"
  Right, false -> "◀"
  Bottom, true -> "▼"
  Bottom, false -> "▲"
  _, true -> "−"
  _, false -> "+"

panelStyle :: PanelConfig -> String
panelStyle config =
  let
    width = case config.width of
      Just w -> "width: " <> w <> ";"
      Nothing -> ""
    height = case config.height of
      Just h -> "height: " <> h <> ";"
      Nothing -> ""
  in
    width <> height

-- | Placeholder component for slots
placeholderComponent :: forall m. H.Component (Const Void) Unit Void m
placeholderComponent = H.mkComponent
  { initialState: identity
  , render: \_ -> HH.text ""
  , eval: H.mkEval H.defaultEval
  }

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action ShellSlots ShellOutput m Unit
handleAction = case _ of
  Initialize -> do
    state <- H.get
    when state.config.enableZoom do
      -- Zoom attachment would happen here via FFI
      -- For now, just log that we'd attach zoom
      pure unit

  HandleTogglePanel panelId -> do
    state <- H.get
    let currentOpen = fromMaybe false $ Map.lookup panelId state.panelStates
    let newOpen = not currentOpen
    H.modify_ \s -> s { panelStates = Map.insert panelId newOpen s.panelStates }
    H.raise (PanelToggled panelId newOpen)

  HandleZoomChange newZoom -> do
    H.modify_ _ { zoom = newZoom }
    H.raise (ZoomChanged newZoom)

  Receive input -> do
    H.modify_ \s -> s
      { config = input.config
      , panels = input.panels
      }

handleQuery :: forall m a. ShellQuery a -> H.HalogenM State Action ShellSlots ShellOutput m (Maybe a)
handleQuery = case _ of
  SetPanelOpen panelId open reply -> do
    state <- H.get
    let currentOpen = Map.lookup panelId state.panelStates
    when (currentOpen /= Just open) do
      H.modify_ \s -> s { panelStates = Map.insert panelId open s.panelStates }
      H.raise (PanelToggled panelId open)
    pure (Just reply)

  TogglePanel panelId reply -> do
    state <- H.get
    let currentOpen = fromMaybe false $ Map.lookup panelId state.panelStates
    let newOpen = not currentOpen
    H.modify_ \s -> s { panelStates = Map.insert panelId newOpen s.panelStates }
    H.raise (PanelToggled panelId newOpen)
    pure (Just reply)

  GetZoom reply -> do
    state <- H.get
    pure (Just (reply state.zoom))

  SetZoom newZoom reply -> do
    H.modify_ _ { zoom = newZoom }
    H.raise (ZoomChanged newZoom)
    pure (Just reply)
