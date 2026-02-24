-- | PSD3.React.Hooks - React integration for PSD3 visualizations
-- |
-- | This module provides utilities for using PSD3 within React components
-- | built with purescript-react-basic-hooks.
-- |
-- | ## Usage
-- |
-- | ```purescript
-- | import Hylograph.React.Hooks (useContainerId)
-- |
-- | mkBarChart :: Component { data :: Array Number }
-- | mkBarChart = do
-- |   containerId <- useContainerId
-- |   component "BarChart" \props -> React.do
-- |
-- |     useEffectOnce do
-- |       runD3 do
-- |         container <- select ("#" <> containerId)
-- |         clear container
-- |         renderTree container (barChartAST props.data)
-- |       pure mempty
-- |
-- |     pure $ R.div { id: containerId }
-- | ```
module PSD3.React.Hooks
  ( useContainerId
  ) where

import Effect (Effect)

-- | Foreign function to generate unique IDs
foreign import generateContainerIdImpl :: Effect String

-- | Generate a unique container ID for a PSD3 visualization.
-- |
-- | Call this once when creating your component (outside React.do),
-- | then use the ID in your JSX and D3 select call.
-- |
-- | ```purescript
-- | mkMyViz :: Component Props
-- | mkMyViz = do
-- |   containerId <- useContainerId
-- |   component "MyViz" \props -> React.do
-- |     -- use containerId in useEffect and JSX
-- | ```
useContainerId :: Effect String
useContainerId = generateContainerIdImpl
