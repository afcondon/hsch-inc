-- | Matrix View: Interpreter × Expression Coverage
-- |
-- | Shows which interpreters implement which expression classes
-- | as an interactive heatmap grid.
module TypeExplorer.Views.Matrix
  ( initMatrixView
  , MatrixHandle
  ) where

import Prelude

import Data.Array as Array
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Ref as Ref
import Hylograph.HATS (Tree, elem, staticStr, staticNum, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))
import TypeExplorer.Types (InterpreterMatrix, InterpreterInfo, ExpressionClassInfo, colors)

-- =============================================================================
-- Types
-- =============================================================================

type MatrixConfig =
  { width :: Number
  , height :: Number
  , cellSize :: Number
  , headerHeight :: Number
  , labelWidth :: Number
  , padding :: Number
  }

defaultConfig :: MatrixConfig
defaultConfig =
  { width: 900.0
  , height: 600.0
  , cellSize: 40.0
  , headerHeight: 120.0
  , labelWidth: 150.0
  , padding: 20.0
  }

type MatrixHandle =
  { onCellClick :: ((String -> String -> Effect Unit) -> Effect Unit)
  }

-- =============================================================================
-- Public API
-- =============================================================================

-- | Initialize the matrix view
initMatrixView :: String -> InterpreterMatrix -> Effect MatrixHandle
initMatrixView selector matrixData = do
  let config = defaultConfig

  -- Click callback ref
  clickCallbackRef <- Ref.new (\_ _ -> pure unit :: Effect Unit)

  -- Render the matrix
  _ <- rerender selector (renderMatrix config matrixData clickCallbackRef)

  pure
    { onCellClick: \callback -> Ref.write callback clickCallbackRef
    }

-- =============================================================================
-- Rendering
-- =============================================================================

-- | Render the full matrix
renderMatrix :: MatrixConfig -> InterpreterMatrix -> Ref.Ref (String -> String -> Effect Unit) -> Tree
renderMatrix config matrixData _callbackRef =
  elem SVG
    [ staticStr "viewBox" $ "0 0 " <> show config.width <> " " <> show config.height
    , staticStr "width" "100%"
    , staticStr "height" "100%"
    , staticStr "class" "matrix-view"
    ]
    [ -- Background
      elem Rect
        [ staticStr "fill" colors.bg
        , staticStr "width" (show config.width)
        , staticStr "height" (show config.height)
        ] []
    , -- Title
      elem Text
        [ staticStr "x" (show config.padding)
        , staticStr "y" "30"
        , staticStr "font-size" "18"
        , staticStr "font-weight" "bold"
        , staticStr "fill" colors.text
        , staticStr "textContent" "Interpreter × Expression Coverage"
        ] []
    , -- Subtitle with stats
      elem Text
        [ staticStr "x" (show config.padding)
        , staticStr "y" "50"
        , staticStr "font-size" "12"
        , staticStr "fill" "#666"
        , thunkedStr "textContent" $
            show (Array.length matrixData.interpreters) <> " interpreters, " <>
            show (Array.length matrixData.expressionClasses) <> " expression classes"
        ] []
    , -- Column headers (expression classes) - rotated
      renderColumnHeaders config matrixData.expressionClasses
    , -- Row labels (interpreters) and cells
      renderRows config matrixData
    , -- Legend
      renderLegend config
    ]

-- | Render rotated column headers
renderColumnHeaders :: MatrixConfig -> Array ExpressionClassInfo -> Tree
renderColumnHeaders config classes =
  let
    startX = config.padding + config.labelWidth
    startY = config.headerHeight - 10.0
  in
    elem Group
      [ staticStr "class" "column-headers" ]
      (Array.mapWithIndex (renderColumnHeader config startX startY) classes)

renderColumnHeader :: MatrixConfig -> Number -> Number -> Int -> ExpressionClassInfo -> Tree
renderColumnHeader config startX startY idx exprClass =
  let x = startX + toNumber idx * config.cellSize + config.cellSize / 2.0
  in
    elem Text
      [ thunkedStr "x" (show x)
      , thunkedStr "y" (show startY)
      , staticStr "text-anchor" "start"
      , staticStr "font-size" "10"
      , staticStr "fill" colors.text
      , staticStr "transform" $ "rotate(-45, " <> show x <> ", " <> show startY <> ")"
      , staticStr "textContent" exprClass.name
      ] []

-- | Render all rows (interpreters + cells)
renderRows :: MatrixConfig -> InterpreterMatrix -> Tree
renderRows config matrixData =
  let
    startY = config.headerHeight
  in
    elem Group
      [ staticStr "class" "rows" ]
      (Array.mapWithIndex (renderRow config matrixData startY) matrixData.interpreters)

renderRow :: MatrixConfig -> InterpreterMatrix -> Number -> Int -> InterpreterInfo -> Tree
renderRow config matrixData startY rowIdx interpreter =
  let
    y = startY + toNumber rowIdx * config.cellSize
    rowData = case Array.index matrixData.matrix rowIdx of
      Just cells -> cells
      Nothing -> []
  in
    elem Group
      [ staticStr "class" "row" ]
      [ -- Row label
        elem Text
          [ staticStr "x" (show config.padding)
          , thunkedStr "y" (show (y + config.cellSize / 2.0 + 4.0))
          , staticStr "font-size" "11"
          , staticStr "fill" colors.text
          , staticStr "textContent" interpreter.name
          ] []
      , -- Cells
        elem Group
          [ staticStr "class" "cells" ]
          (Array.mapWithIndex (renderCell config y) rowData)
      ]

renderCell :: MatrixConfig -> Number -> Int -> Boolean -> Tree
renderCell config rowY colIdx implemented =
  let
    x = config.padding + config.labelWidth + toNumber colIdx * config.cellSize
  in
    elem Rect
      [ thunkedStr "x" (show (x + 2.0))
      , thunkedStr "y" (show (rowY + 2.0))
      , staticNum "width" (config.cellSize - 4.0)
      , staticNum "height" (config.cellSize - 4.0)
      , staticNum "rx" 4.0
      , staticStr "fill" $ if implemented then colors.instanceProvider else "#e0e0e0"
      , staticNum "opacity" $ if implemented then 0.9 else 0.3
      , staticStr "stroke" $ if implemented then "#2e7d32" else "#ccc"
      , staticNum "stroke-width" 1.0
      ] []

-- | Render legend
renderLegend :: MatrixConfig -> Tree
renderLegend config =
  let
    x = config.width - 180.0
    y = config.height - 60.0
  in
    elem Group
      [ staticStr "class" "legend"
      , staticStr "transform" $ "translate(" <> show x <> ", " <> show y <> ")"
      ]
      [ elem Rect
          [ staticStr "x" "0", staticStr "y" "0"
          , staticStr "width" "20", staticStr "height" "20"
          , staticStr "fill" colors.instanceProvider
          , staticStr "rx" "4"
          ] []
      , elem Text
          [ staticStr "x" "28", staticStr "y" "14"
          , staticStr "font-size" "11"
          , staticStr "fill" colors.text
          , staticStr "textContent" "Implemented"
          ] []
      , elem Rect
          [ staticStr "x" "0", staticStr "y" "28"
          , staticStr "width" "20", staticStr "height" "20"
          , staticStr "fill" "#e0e0e0"
          , staticStr "opacity" "0.3"
          , staticStr "rx" "4"
          ] []
      , elem Text
          [ staticStr "x" "28", staticStr "y" "42"
          , staticStr "font-size" "11"
          , staticStr "fill" colors.text
          , staticStr "textContent" "Not implemented"
          ] []
      ]
