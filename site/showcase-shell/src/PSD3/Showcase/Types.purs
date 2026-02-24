module PSD3.Showcase.Types
  ( PanelPosition(..)
  , PanelConfig
  , ShellConfig
  , ZoomState
  , defaultShellConfig
  , panelPositionToClass
  ) where

import Prelude

import Data.Maybe (Maybe(..))

-- | Position for floating panels
data PanelPosition
  = Left
  | Right
  | TopLeft
  | TopRight
  | BottomLeft
  | BottomRight
  | Bottom

derive instance eqPanelPosition :: Eq PanelPosition

-- | Configuration for a single panel
type PanelConfig =
  { id :: String
  , position :: PanelPosition
  , width :: Maybe String       -- CSS width (e.g., "320px", "25%")
  , height :: Maybe String      -- CSS height (optional, for bottom panels)
  , initialOpen :: Boolean
  , toggleable :: Boolean
  }

-- | Configuration for the showcase shell
type ShellConfig =
  { headerHeight :: String      -- CSS value (e.g., "60px")
  , enableZoom :: Boolean       -- Whether SVG layer should be zoomable
  , zoomExtent :: { min :: Number, max :: Number }
  , svgId :: String             -- ID for the main SVG element
  , zoomGroupId :: String       -- ID for the zoom transform group
  }

-- | Zoom transform state (matches D3's transform)
type ZoomState =
  { k :: Number   -- scale
  , x :: Number   -- translate x
  , y :: Number   -- translate y
  }

-- | Default shell configuration
defaultShellConfig :: ShellConfig
defaultShellConfig =
  { headerHeight: "60px"
  , enableZoom: true
  , zoomExtent: { min: 0.1, max: 10.0 }
  , svgId: "showcase-svg"
  , zoomGroupId: "showcase-zoom-group"
  }

-- | Convert panel position to CSS class suffix
panelPositionToClass :: PanelPosition -> String
panelPositionToClass = case _ of
  Left -> "left"
  Right -> "right"
  TopLeft -> "top-left"
  TopRight -> "top-right"
  BottomLeft -> "bottom-left"
  BottomRight -> "bottom-right"
  Bottom -> "bottom"
