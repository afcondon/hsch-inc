module App where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA
import Hylograph.Internal.Behavior.FFI (ZoomTransform, attachZoomWithCallback_)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window (document)

type State =
  { leftPanelOpen :: Boolean
  , bottomPanelOpen :: Boolean
  , circleCount :: Int
  , zoom :: ZoomTransform
  }

data Action
  = Initialize
  | ToggleLeftPanel
  | ToggleBottomPanel
  | AddCircle
  | RemoveCircle
  | ZoomChanged ZoomTransform

component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ ->
      { leftPanelOpen: true
      , bottomPanelOpen: true
      , circleCount: 5
      , zoom: { k: 1.0, x: 0.0, y: 0.0 }
      }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div
    [ HP.classes [ HH.ClassName "showcase-shell" ] ]
    [ -- Header
      HH.header
        [ HP.classes [ HH.ClassName "showcase-header", HH.ClassName "showcase-header--transparent" ] ]
        [ HH.div
            [ HP.style "display: flex; align-items: center; gap: 1rem;" ]
            [ HH.h1
                [ HP.style "margin: 0; font-size: 1.25rem; font-weight: 600;" ]
                [ HH.text "Showcase Shell Demo" ]
            , HH.span
                [ HP.style "color: var(--psd3-text-muted);" ]
                [ HH.text "Testing the layout framework" ]
            ]
        , HH.nav
            [ HP.style "display: flex; gap: 0.5rem;" ]
            [ HH.button
                [ HP.classes [ HH.ClassName "btn", HH.ClassName "btn--secondary" ]
                , HE.onClick \_ -> ToggleLeftPanel
                ]
                [ HH.text $ if state.leftPanelOpen then "Hide Panel" else "Show Panel" ]
            ]
        ]

    -- Main content area
    , HH.div
        [ HP.classes [ HH.ClassName "showcase-main" ] ]
        [ -- SVG layer
          HH.div
            [ HP.classes [ HH.ClassName "showcase-svg-layer" ]
            , HP.id "showcase-svg-container"
            ]
            [ SE.svg
                [ SA.viewBox 0.0 0.0 800.0 600.0
                , HP.style "width: 100%; height: 100%;"
                , HP.id "demo-svg"
                ]
                [ -- Zoom group - this receives the transform
                  SE.g
                    [ HP.attr (HH.AttrName "class") "zoom-group" ]
                    [ -- Background
                      SE.rect
                        [ SA.width 800.0
                        , SA.height 600.0
                        , SA.fill (SA.RGB 250 250 250)
                        ]
                    -- Grid lines (horizontal)
                    , SE.g [] (renderGridLines true)
                    -- Grid lines (vertical)
                    , SE.g [] (renderGridLines false)
                    -- Demo circles
                    , SE.g
                        [ SA.transform [ SA.Translate 400.0 300.0 ] ]
                        (renderCircles state.circleCount)
                    ]
                ]
            ]

        -- Panels container
        , HH.div
            [ HP.classes [ HH.ClassName "showcase-panels" ] ]
            [ -- Left panel
              HH.div
                [ HP.classes $
                    [ HH.ClassName "showcase-panel"
                    , HH.ClassName "showcase-panel--left"
                    ] <> if state.leftPanelOpen
                          then [ HH.ClassName "showcase-panel--open" ]
                          else [ HH.ClassName "showcase-panel--closed" ]
                , HP.id "left-panel"
                ]
                [ HH.button
                    [ HP.classes [ HH.ClassName "showcase-panel-toggle" ]
                    , HE.onClick \_ -> ToggleLeftPanel
                    ]
                    [ HH.text $ if state.leftPanelOpen then "◀" else "▶" ]
                , HH.div
                    [ HP.classes [ HH.ClassName "showcase-panel-content" ] ]
                    [ HH.h3
                        [ HP.style "margin-top: 0;" ]
                        [ HH.text "Controls" ]
                    , HH.p_ [ HH.text "This is a left panel that slides in and out." ]
                    , HH.div
                        [ HP.style "display: flex; flex-direction: column; gap: 0.5rem; margin-top: 1rem;" ]
                        [ HH.button
                            [ HP.classes [ HH.ClassName "btn", HH.ClassName "btn--primary" ]
                            , HE.onClick \_ -> AddCircle
                            ]
                            [ HH.text "Add Circle" ]
                        , HH.button
                            [ HP.classes [ HH.ClassName "btn", HH.ClassName "btn--secondary" ]
                            , HE.onClick \_ -> RemoveCircle
                            ]
                            [ HH.text "Remove Circle" ]
                        , HH.p
                            [ HP.style "margin: 0.5rem 0; color: var(--psd3-text-muted);" ]
                            [ HH.text $ "Circle count: " <> show state.circleCount ]
                        ]
                    ]
                ]

            -- Bottom panel
            , HH.div
                [ HP.classes $
                    [ HH.ClassName "showcase-panel"
                    , HH.ClassName "showcase-panel--bottom"
                    ] <> if state.bottomPanelOpen
                          then [ HH.ClassName "showcase-panel--open" ]
                          else [ HH.ClassName "showcase-panel--closed" ]
                , HP.id "bottom-panel"
                ]
                [ HH.div
                    [ HP.classes [ HH.ClassName "showcase-panel-content" ] ]
                    [ HH.span_ [ HH.text $ "Zoom: " <> formatZoom state.zoom.k ]
                    , HH.span
                        [ HP.style "color: var(--psd3-text-muted);" ]
                        [ HH.text " | " ]
                    , HH.span_ [ HH.text $ show state.circleCount <> " circles" ]
                    , HH.span
                        [ HP.style "color: var(--psd3-text-muted);" ]
                        [ HH.text " | " ]
                    , HH.span_ [ HH.text "Scroll to zoom, drag to pan" ]
                    ]
                ]
            ]
        ]
    ]

formatZoom :: Number -> String
formatZoom k = show (toIntImpl (k * 100.0)) <> "%"

renderGridLines :: forall w i. Boolean -> Array (HH.HTML w i)
renderGridLines isHorizontal =
  map renderLine (range 0 19)
  where
    range start end
      | start > end = []
      | otherwise = [start] <> range (start + 1) end

    renderLine i =
      let pos = toNumberImpl i * 40.0
      in if isHorizontal
        then SE.line
          [ SA.x1 0.0, SA.y1 pos, SA.x2 800.0, SA.y2 pos
          , SA.stroke (SA.RGB 230 230 230)
          , SA.strokeWidth 1.0
          ]
        else SE.line
          [ SA.x1 pos, SA.y1 0.0, SA.x2 pos, SA.y2 600.0
          , SA.stroke (SA.RGB 230 230 230)
          , SA.strokeWidth 1.0
          ]

renderCircles :: forall w i. Int -> Array (HH.HTML w i)
renderCircles count =
  map renderCircle (range 0 (count - 1))
  where
    range start end
      | start > end = []
      | otherwise = [start] <> range (start + 1) end

    renderCircle i =
      let
        angle = (toNumber i / toNumber count) * 6.28318  -- 2*PI
        radius = 100.0
        x = radius * cos angle
        y = radius * sin angle
        hue = (toNumber i / toNumber count) * 360.0
      in
        SE.circle
          [ SA.cx x
          , SA.cy y
          , SA.r 20.0
          , SA.fill (SA.RGB
              (hueToRgb hue 0.7 0.5).r
              (hueToRgb hue 0.7 0.5).g
              (hueToRgb hue 0.7 0.5).b)
          , SA.stroke (SA.RGB 255 255 255)
          , SA.strokeWidth 2.0
          ]

    toNumber :: Int -> Number
    toNumber = toNumberImpl

    cos :: Number -> Number
    cos = cosImpl

    sin :: Number -> Number
    sin = sinImpl

-- HSL to RGB conversion (simplified)
hueToRgb :: Number -> Number -> Number -> { r :: Int, g :: Int, b :: Int }
hueToRgb h s l =
  let
    c = (1.0 - abs (2.0 * l - 1.0)) * s
    x = c * (1.0 - abs (mod' (h / 60.0) 2.0 - 1.0))
    m = l - c / 2.0
    rgb' = case unit of
      _ | h < 60.0  -> { r: c, g: x, b: 0.0 }
        | h < 120.0 -> { r: x, g: c, b: 0.0 }
        | h < 180.0 -> { r: 0.0, g: c, b: x }
        | h < 240.0 -> { r: 0.0, g: x, b: c }
        | h < 300.0 -> { r: x, g: 0.0, b: c }
        | otherwise -> { r: c, g: 0.0, b: x }
  in
    { r: toInt ((rgb'.r + m) * 255.0)
    , g: toInt ((rgb'.g + m) * 255.0)
    , b: toInt ((rgb'.b + m) * 255.0)
    }
  where
    abs n = if n < 0.0 then -n else n
    mod' a b = a - b * floor (a / b)
    floor = floorImpl
    toInt = toIntImpl

foreign import toNumberImpl :: Int -> Number
foreign import cosImpl :: Number -> Number
foreign import sinImpl :: Number -> Number
foreign import floorImpl :: Number -> Number
foreign import toIntImpl :: Number -> Int

handleAction :: forall o m. MonadAff m => Action -> H.HalogenM State Action () o m Unit
handleAction = case _ of
  Initialize -> do
    -- Attach zoom behavior after component mounts
    H.liftEffect do
      attachZoom
    pure unit

  ToggleLeftPanel ->
    H.modify_ \s -> s { leftPanelOpen = not s.leftPanelOpen }

  ToggleBottomPanel ->
    H.modify_ \s -> s { bottomPanelOpen = not s.bottomPanelOpen }

  AddCircle ->
    H.modify_ \s -> s { circleCount = min 12 (s.circleCount + 1) }

  RemoveCircle ->
    H.modify_ \s -> s { circleCount = max 1 (s.circleCount - 1) }

  ZoomChanged newZoom ->
    H.modify_ \s -> s { zoom = newZoom }

-- | Attach D3 zoom behavior to the SVG
attachZoom :: Effect Unit
attachZoom = do
  win <- window
  doc <- document win
  let nonElemNode = HTMLDocument.toNonElementParentNode doc
  maybeSvg <- getElementById "demo-svg" nonElemNode
  case maybeSvg of
    Nothing -> pure unit
    Just svgElem -> do
      let initialZoom = { k: 1.0, x: 0.0, y: 0.0 }
      -- We can't easily callback to Halogen from here, so just attach zoom
      -- The transform updates the .zoom-group element directly via D3
      _ <- attachZoomWithCallback_ svgElem 0.1 10.0 ".zoom-group" initialZoom (\_ -> pure unit)
      pure unit
