-- | Type Classes Splitscreen View
-- |
-- | Combines the Matrix (Interpreter × Expression) view and
-- | TypeClass Grid view into a single splitscreen layout.
-- | Each pane is independently scrollable.
module TypeExplorer.Views.TypeClassesSplit
  ( initTypeClassesSplit
  , TypeClassesSplitHandle
  ) where

import Prelude

import Data.Array as Array
import Data.Int (toNumber)
import Data.Int (floor) as Int
import Data.Maybe (Maybe(..))
import Data.Number (pi, cos, sin)
import Data.String.Pattern (Pattern(..))
import Data.String.Common (split) as StringCommon
import Effect (Effect)
import Effect.Ref as Ref
import Hylograph.HATS (Tree, elem, staticStr, staticNum, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender, clearContainer)
import Hylograph.Internal.Selection.Types (ElementType(..))
import TypeExplorer.Types (InterpreterMatrix, InterpreterInfo, ExpressionClassInfo,
                           TypeClassGridData, TypeClassGridInfo, colors)

-- =============================================================================
-- Types
-- =============================================================================

type SplitConfig =
  { width :: Number
  , height :: Number
  , splitRatio :: Number  -- 0.5 = 50/50 split
  , gap :: Number         -- Gap between panes
  }

defaultConfig :: SplitConfig
defaultConfig =
  { width: 1200.0
  , height: 800.0
  , splitRatio: 0.5
  , gap: 20.0
  }

type TypeClassesSplitHandle =
  { onCellClick :: ((String -> String -> Effect Unit) -> Effect Unit)
  , onClassClick :: ((Int -> Effect Unit) -> Effect Unit)
  }

-- =============================================================================
-- Public API
-- =============================================================================

-- | Initialize the splitscreen view
initTypeClassesSplit :: String -> InterpreterMatrix -> TypeClassGridData -> Effect TypeClassesSplitHandle
initTypeClassesSplit selector matrixData gridData = do
  let config = defaultConfig

  -- Clear existing content
  clearContainer selector

  -- Click callback refs
  cellCallbackRef <- Ref.new (\_ _ -> pure unit :: Effect Unit)
  classCallbackRef <- Ref.new (\_ -> pure unit :: Effect Unit)

  -- Render the splitscreen
  _ <- rerender selector (renderSplit config matrixData gridData)

  pure
    { onCellClick: \callback -> Ref.write callback cellCallbackRef
    , onClassClick: \callback -> Ref.write callback classCallbackRef
    }

-- =============================================================================
-- Splitscreen Rendering
-- =============================================================================

-- | Render the full splitscreen layout
renderSplit :: SplitConfig -> InterpreterMatrix -> TypeClassGridData -> Tree
renderSplit config matrixData gridData =
  let
    leftWidth = (config.width - config.gap) * config.splitRatio
    rightWidth = (config.width - config.gap) * (1.0 - config.splitRatio)
    rightX = leftWidth + config.gap
  in
    elem SVG
      [ staticStr "viewBox" $ "0 0 " <> show config.width <> " " <> show config.height
      , staticStr "width" "100%"
      , staticStr "height" "100%"
      , staticStr "class" "typeclasses-split"
      ]
      [ -- Background
        elem Rect
          [ staticStr "x" "0", staticStr "y" "0"
          , thunkedStr "width" (show config.width)
          , thunkedStr "height" (show config.height)
          , staticStr "fill" colors.bg
          ] []
      , -- Left pane: Matrix view
        elem Group
          [ staticStr "class" "left-pane"
          , staticStr "transform" "translate(0, 0)"
          ]
          [ renderMatrixPane leftWidth config.height matrixData ]
      , -- Divider
        elem Rect
          [ thunkedStr "x" (show leftWidth)
          , staticStr "y" "0"
          , thunkedStr "width" (show config.gap)
          , thunkedStr "height" (show config.height)
          , staticStr "fill" "#e0e0e0"
          ] []
      , -- Right pane: TypeClass grid
        elem Group
          [ staticStr "class" "right-pane"
          , thunkedStr "transform" $ "translate(" <> show rightX <> ", 0)"
          ]
          [ renderGridPane rightWidth config.height gridData ]
      ]

-- =============================================================================
-- Matrix Pane (Left)
-- =============================================================================

renderMatrixPane :: Number -> Number -> InterpreterMatrix -> Tree
renderMatrixPane _width _height matrixData =
  let
    padding = 15.0
    headerHeight = 100.0
    cellSize = 35.0
    labelWidth = 100.0
    startY = headerHeight
    startX = padding + labelWidth
  in
    elem Group
      [ staticStr "class" "matrix-pane" ]
      [ -- Title
        elem Text
          [ staticStr "x" (show padding)
          , staticStr "y" "25"
          , staticStr "font-size" "14"
          , staticStr "font-weight" "bold"
          , staticStr "fill" colors.text
          , staticStr "textContent" "Interpreter Coverage"
          ] []
      , -- Subtitle
        elem Text
          [ staticStr "x" (show padding)
          , staticStr "y" "42"
          , staticStr "font-size" "10"
          , staticStr "fill" "#666"
          , thunkedStr "textContent" $
              show (Array.length matrixData.interpreters) <> " interpreters × " <>
              show (Array.length matrixData.expressionClasses) <> " classes"
          ] []
      , -- Column headers
        renderMatrixHeaders startX (headerHeight - 15.0) cellSize matrixData.expressionClasses
      , -- Rows
        renderMatrixRows padding startX startY cellSize labelWidth matrixData
      ]

renderMatrixHeaders :: Number -> Number -> Number -> Array ExpressionClassInfo -> Tree
renderMatrixHeaders startX startY cellSize classes =
  elem Group
    [ staticStr "class" "column-headers" ]
    (Array.mapWithIndex (renderMatrixHeader startX startY cellSize) classes)

renderMatrixHeader :: Number -> Number -> Number -> Int -> ExpressionClassInfo -> Tree
renderMatrixHeader startX startY cellSize idx exprClass =
  let x = startX + toNumber idx * cellSize + cellSize / 2.0
  in
    elem Text
      [ thunkedStr "x" (show x)
      , thunkedStr "y" (show startY)
      , staticStr "text-anchor" "start"
      , staticStr "font-size" "9"
      , staticStr "fill" colors.text
      , staticStr "transform" $ "rotate(-45, " <> show x <> ", " <> show startY <> ")"
      , staticStr "textContent" exprClass.name
      ] []

renderMatrixRows :: Number -> Number -> Number -> Number -> Number -> InterpreterMatrix -> Tree
renderMatrixRows padding startX startY cellSize labelWidth matrixData =
  elem Group
    [ staticStr "class" "rows" ]
    (Array.mapWithIndex (renderMatrixRow padding startX startY cellSize labelWidth matrixData) matrixData.interpreters)

renderMatrixRow :: Number -> Number -> Number -> Number -> Number -> InterpreterMatrix -> Int -> InterpreterInfo -> Tree
renderMatrixRow padding startX startY cellSize _labelWidth matrixData rowIdx interpreter =
  let
    y = startY + toNumber rowIdx * cellSize
    rowData = case Array.index matrixData.matrix rowIdx of
      Just cells -> cells
      Nothing -> []
  in
    elem Group
      [ staticStr "class" "row" ]
      [ -- Row label
        elem Text
          [ staticStr "x" (show padding)
          , thunkedStr "y" (show (y + cellSize / 2.0 + 3.0))
          , staticStr "font-size" "9"
          , staticStr "fill" colors.text
          , staticStr "textContent" interpreter.name
          ] []
      , -- Cells
        elem Group
          [ staticStr "class" "cells" ]
          (Array.mapWithIndex (renderMatrixCell startX y cellSize) rowData)
      ]

renderMatrixCell :: Number -> Number -> Number -> Int -> Boolean -> Tree
renderMatrixCell startX rowY cellSize colIdx implemented =
  let
    x = startX + toNumber colIdx * cellSize
  in
    elem Rect
      [ thunkedStr "x" (show (x + 2.0))
      , thunkedStr "y" (show (rowY + 2.0))
      , staticNum "width" (cellSize - 4.0)
      , staticNum "height" (cellSize - 4.0)
      , staticNum "rx" 3.0
      , staticStr "fill" $ if implemented then colors.instanceProvider else "#e8e8e8"
      , staticNum "opacity" $ if implemented then 0.85 else 0.4
      , staticStr "stroke" $ if implemented then "#2e7d32" else "#ccc"
      , staticNum "stroke-width" 1.0
      ] []

-- =============================================================================
-- TypeClass Grid Pane (Right)
-- =============================================================================

renderGridPane :: Number -> Number -> TypeClassGridData -> Tree
renderGridPane width _height stats =
  let
    padding = 15.0
    cardWidth = 100.0
    cardHeight = 85.0
    cardPadding = 8.0
    startY = 60.0
    cols = max 1.0 $ (width - padding * 2.0) / (cardWidth + cardPadding)
  in
    elem Group
      [ staticStr "class" "grid-pane" ]
      [ -- Title
        elem Text
          [ staticStr "x" (show padding)
          , staticStr "y" "25"
          , staticStr "font-size" "14"
          , staticStr "font-weight" "bold"
          , staticStr "fill" colors.text
          , thunkedStr "textContent" $ show stats.count <> " Type Classes"
          ] []
      , -- Subtitle
        elem Text
          [ staticStr "x" (show padding)
          , staticStr "y" "42"
          , staticStr "font-size" "10"
          , staticStr "fill" "#666"
          , thunkedStr "textContent" $ show stats.summary.totalMethods <> " methods, " <>
                show stats.summary.totalInstances <> " instances"
          ] []
      , -- Cards
        elem Group
          [ staticStr "class" "cards" ]
          (Array.mapWithIndex (positionCard cols cardWidth cardHeight cardPadding padding startY) stats.typeClasses)
      ]

positionCard :: Number -> Number -> Number -> Number -> Number -> Number -> Int -> TypeClassGridInfo -> Tree
positionCard cols cardWidth cardHeight cardPadding startX startY idx tc =
  let
    colsInt = max 1 $ Int.floor cols
    col = toNumber (idx `mod` colsInt)
    row = toNumber (idx / colsInt)
    x = startX + col * (cardWidth + cardPadding)
    y = startY + row * (cardHeight + cardPadding)
  in
    renderCard cardWidth cardHeight x y tc

renderCard :: Number -> Number -> Number -> Number -> TypeClassGridInfo -> Tree
renderCard w h x y tc =
  let
    donutCx = w / 2.0
    donutCy = h / 2.0 - 8.0
    donutRadius = 28.0
  in
    elem Group
      [ staticStr "class" "type-class-card"
      , thunkedStr "transform" $ "translate(" <> show x <> "," <> show y <> ")"
      ]
      [ -- Card background
        elem Rect
          [ staticStr "x" "0", staticStr "y" "0"
          , staticStr "width" (show w)
          , staticStr "height" (show h)
          , staticStr "fill" "#2a2a3e"
          , staticStr "rx" "6"
          , staticStr "stroke" "#3a3a4e"
          , staticStr "stroke-width" "1"
          ] []
      , -- Donut
        renderDonut donutCx donutCy donutRadius tc.methodCount tc.instanceCount 12
      , -- Class name
        elem Text
          [ thunkedStr "x" (show (w / 2.0))
          , thunkedStr "y" (show (h - 15.0))
          , staticStr "text-anchor" "middle"
          , staticStr "font-size" "9"
          , staticStr "font-weight" "600"
          , staticStr "fill" "#e2e8f0"
          , thunkedStr "textContent" tc.name
          ] []
      , -- Module name
        elem Text
          [ thunkedStr "x" (show (w / 2.0))
          , thunkedStr "y" (show (h - 5.0))
          , staticStr "text-anchor" "middle"
          , staticStr "font-size" "6"
          , staticStr "fill" "#64748b"
          , thunkedStr "textContent" $ truncateModule tc.moduleName
          ] []
      ]

-- =============================================================================
-- Donut Chart
-- =============================================================================

renderDonut :: Number -> Number -> Number -> Int -> Int -> Int -> Tree
renderDonut cx cy radius methodCount instanceCount maxMethods =
  let
    displayCount = min methodCount maxMethods
    arcs = if displayCount <= 0
           then [ renderEmptyRing cx cy radius ]
           else Array.mapWithIndex (renderMethodArc cx cy radius displayCount) (Array.range 0 (displayCount - 1))
    centerText = elem Text
      [ thunkedStr "x" (show cx)
      , thunkedStr "y" (show (cy + 5.0))
      , staticStr "text-anchor" "middle"
      , staticStr "font-size" "12"
      , staticStr "font-weight" "bold"
      , staticStr "fill" $ instanceCountColor instanceCount
      , thunkedStr "textContent" $ show instanceCount
      ] []
  in
    elem Group
      [ staticStr "class" "donut" ]
      (Array.snoc arcs centerText)

renderEmptyRing :: Number -> Number -> Number -> Tree
renderEmptyRing cx cy r =
  elem Circle
    [ thunkedStr "cx" (show cx)
    , thunkedStr "cy" (show cy)
    , thunkedStr "r" (show (r - 5.0))
    , staticStr "fill" "none"
    , staticStr "stroke" "#334155"
    , staticStr "stroke-width" "6"
    ] []

renderMethodArc :: Number -> Number -> Number -> Int -> Int -> Int -> Tree
renderMethodArc cx cy radius total idx _ =
  let
    gap = 0.08
    arcLength = (2.0 * pi - toNumber total * gap) / toNumber total
    startAngle = toNumber idx * (arcLength + gap) - pi / 2.0
    endAngle = startAngle + arcLength

    innerR = radius - 6.0
    outerR = radius - 1.0

    x1 = cx + outerR * cos startAngle
    y1 = cy + outerR * sin startAngle
    x2 = cx + outerR * cos endAngle
    y2 = cy + outerR * sin endAngle
    x3 = cx + innerR * cos endAngle
    y3 = cy + innerR * sin endAngle
    x4 = cx + innerR * cos startAngle
    y4 = cy + innerR * sin startAngle

    largeArc = if arcLength > pi then "1" else "0"

    d = "M " <> show x1 <> " " <> show y1
      <> " A " <> show outerR <> " " <> show outerR <> " 0 " <> largeArc <> " 1 " <> show x2 <> " " <> show y2
      <> " L " <> show x3 <> " " <> show y3
      <> " A " <> show innerR <> " " <> show innerR <> " 0 " <> largeArc <> " 0 " <> show x4 <> " " <> show y4
      <> " Z"
  in
    elem Path
      [ thunkedStr "d" d
      , staticStr "fill" "#f59e0b"
      , staticStr "opacity" "0.85"
      ] []

-- =============================================================================
-- Helpers
-- =============================================================================

instanceCountColor :: Int -> String
instanceCountColor n
  | n >= 100 = "#22c55e"   -- Green - heavily used
  | n >= 20 = "#eab308"    -- Yellow - moderate
  | n >= 1 = "#94a3b8"     -- Gray - light use
  | otherwise = "#475569"  -- Dim - no instances

truncateModule :: String -> String
truncateModule s =
  let parts = StringCommon.split (Pattern ".") s
      len = Array.length parts
  in if len <= 2
     then s
     else "..." <> (Array.intercalate "." $ Array.drop (len - 2) parts)
