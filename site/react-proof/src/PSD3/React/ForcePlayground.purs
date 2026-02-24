-- | Force Playground - React version using useSimulation hook
-- |
-- | This demonstrates the useSimulation hook with:
-- | - Procedurally generated network data
-- | - Force simulation lifecycle management
-- | - Callback handlers for simulation events
-- | - UI controls for regeneration and status display
module PSD3.React.ForcePlayground
  ( mkForcePlayground
  , ForcePlaygroundProps
  ) where

import Prelude

import Data.Array as Array
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Nullable as Nullable
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Random (randomInt, random)
import Hylograph.React.Hooks (useContainerId)
import Hylograph.React.Simulation (useSimulationWithCallbacks, SimulationCallbackHandlers)
import Hylograph.ForceEngine.Setup as Setup
import React.Basic.DOM as R
import React.Basic.DOM.Events (capture_)
import React.Basic.Hooks (Component, component, useState, useEffect, useEffectOnce)
import React.Basic.Hooks as React

-- =============================================================================
-- Types
-- =============================================================================

-- | Node type for our force simulation
type PlaygroundNode =
  { id :: Int
  , x :: Number
  , y :: Number
  , vx :: Number
  , vy :: Number
  , fx :: Nullable.Nullable Number
  , fy :: Nullable.Nullable Number
  , group :: Int           -- Category (0-3)
  , importance :: Number   -- 0.0-1.0
  }

-- | Link type
type PlaygroundLink =
  { source :: Int
  , target :: Int
  , weight :: Number       -- 0.0-1.0
  }

-- | Node info passed to click callback
type NodeInfo =
  { id :: Int
  , group :: Int
  , groupName :: String
  , importance :: Number
  }

-- | Component props
type ForcePlaygroundProps = {}

-- =============================================================================
-- Force Setup Configuration
-- =============================================================================

-- | Standard force configuration
forceSetup :: Setup.Setup PlaygroundNode
forceSetup = Setup.setup "playground"
  [ Setup.manyBody "charge" # Setup.withStrength (Setup.static (-50.0))
  , Setup.link "links" # Setup.withDistance (Setup.static 40.0)
  , Setup.center "center"
  , Setup.collide "collision" # Setup.withRadius (Setup.static 8.0)
  ]

-- =============================================================================
-- Data Generation
-- =============================================================================

-- | Generate random network data
generateNetwork :: Int -> Effect { nodes :: Array PlaygroundNode, links :: Array PlaygroundLink }
generateNetwork nodeCount = do
  nodes <- generateNodes nodeCount
  links <- generateLinks nodeCount
  pure { nodes, links }

-- | Generate nodes with random attributes
generateNodes :: Int -> Effect (Array PlaygroundNode)
generateNodes count = do
  Array.foldM
    (\acc i -> do
      group <- randomInt 0 3
      importance <- random
      -- Random initial positions in a circle
      angle <- random
      radius <- random
      let x = (radius * 200.0) * cos (angle * 6.28)
          y = (radius * 200.0) * sin (angle * 6.28)
      pure $ acc <>
        [ { id: i
          , x
          , y
          , vx: 0.0
          , vy: 0.0
          , fx: Nullable.null
          , fy: Nullable.null
          , group
          , importance
          }
        ]
    )
    []
    (Array.range 0 (count - 1))

-- | Generate links (connect some random pairs)
generateLinks :: Int -> Effect (Array PlaygroundLink)
generateLinks nodeCount = do
  -- Target about 1.5x links as nodes
  let targetLinks = (nodeCount * 3) / 2
  Array.foldM
    (\acc _ -> do
      source <- randomInt 0 (nodeCount - 1)
      target <- randomInt 0 (nodeCount - 1)
      weight <- random
      if source /= target
        then pure $ acc <> [{ source, target, weight }]
        else pure acc
    )
    []
    (Array.range 0 targetLinks)

-- =============================================================================
-- Rendering
-- =============================================================================

-- | Render the visualization to SVG with click callback
foreign import renderPlaygroundWithCallback
  :: String                    -- Container ID
  -> Array PlaygroundNode      -- Nodes
  -> Array PlaygroundLink      -- Links
  -> (NodeInfo -> Effect Unit) -- Click callback
  -> Effect Unit


-- =============================================================================
-- Component
-- =============================================================================

-- | Force Playground component using useSimulation hook
mkForcePlayground :: Component ForcePlaygroundProps
mkForcePlayground = do
  containerId <- useContainerId

  component "ForcePlayground" \_props -> React.do
    -- State for generated data
    nodes /\ setNodes <- useState ([] :: Array PlaygroundNode)
    links /\ setLinks <- useState ([] :: Array PlaygroundLink)

    -- State for simulation status (updated via callbacks)
    status /\ setStatus <- useState "Initializing..."

    -- State for node info display (callback test)
    selectedNode /\ setSelectedNode <- useState (Nothing :: Maybe NodeInfo)

    -- Callback handlers - tick count now comes from the hook
    let handlers :: SimulationCallbackHandlers
        handlers =
          { onTick: pure unit  -- tick count is managed by the hook
          , onStart: setStatus \_ -> "Running..."
          , onStop: setStatus \_ -> "Settled"
          , onAlphaThreshold: \a ->
              when (a < 0.1) $ setStatus \_ -> "Almost settled..."
          }

    -- Use the simulation hook with callbacks
    { currentNodes, isRunning, alpha, tickCount } <-
      useSimulationWithCallbacks forceSetup nodes links handlers

    -- Generate initial data on mount
    useEffectOnce do
      network <- generateNetwork 50
      setNodes \_ -> network.nodes
      setLinks \_ -> network.links
      pure mempty

    -- Click handler for nodes
    let handleNodeClick :: NodeInfo -> Effect Unit
        handleNodeClick info = setSelectedNode \_ -> Just info

    -- Render when node positions update
    -- Use tickCount as dependency since PureScript's Eq for arrays compares
    -- contents, and D3 mutates nodes in place (same refs = equal arrays)
    useEffect tickCount do
      when (Array.length currentNodes > 0) do
        renderPlaygroundWithCallback containerId currentNodes links handleNodeClick
      pure mempty

    -- Regenerate handler
    let regenerate = do
          network <- generateNetwork 50
          setNodes \_ -> network.nodes
          setLinks \_ -> network.links
          setStatus \_ -> "Regenerated!"

    -- UI
    pure $ R.div
      { style: R.css
          { fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
          , padding: "20px"
          }
      , children:
          [ -- Title
            R.h1
              { style: R.css { marginBottom: "10px" }
              , children: [ R.text "Force Playground (React)" ]
              }

          , R.p
              { style: R.css { color: "#666", marginBottom: "20px" }
              , children: [ R.text "Testing useSimulation hook with callbacks" ]
              }

          -- Control Panel
          , R.div
              { style: R.css
                  { display: "flex"
                  , gap: "20px"
                  , marginBottom: "20px"
                  , padding: "15px"
                  , background: "#f5f5f5"
                  , borderRadius: "8px"
                  }
              , children:
                  [ -- Regenerate button
                    R.button
                      { onClick: capture_ regenerate
                      , style: R.css
                          { padding: "10px 20px"
                          , background: "#4CAF50"
                          , color: "white"
                          , border: "none"
                          , borderRadius: "4px"
                          , cursor: "pointer"
                          , fontSize: "14px"
                          }
                      , children: [ R.text "Regenerate Network" ]
                      }

                  -- Status display
                  , R.div
                      { style: R.css { display: "flex", flexDirection: "column", gap: "4px" }
                      , children:
                          [ R.span_ [ R.text $ "Status: " <> status ]
                          , R.span_ [ R.text $ "Ticks: " <> show tickCount ]
                          , R.span_ [ R.text $ "Alpha: " <> show (roundTo2 alpha) ]
                          , R.span_ [ R.text $ "Running: " <> show isRunning ]
                          ]
                      }

                  -- Node count
                  , R.div_
                      [ R.span_ [ R.text $ "Nodes: " <> show (Array.length currentNodes) ]
                      , R.br {}
                      , R.span_ [ R.text $ "Links: " <> show (Array.length links) ]
                      ]
                  ]
              }

          -- Modal for selected node (callback test)
          , case selectedNode of
              Nothing -> R.text ""
              Just info -> R.div
                { style: R.css
                    { position: "fixed"
                    , top: "50%"
                    , left: "50%"
                    , transform: "translate(-50%, -50%)"
                    , padding: "24px"
                    , background: "white"
                    , borderRadius: "12px"
                    , boxShadow: "0 8px 32px rgba(0,0,0,0.3)"
                    , zIndex: "1000"
                    , minWidth: "280px"
                    }
                , children:
                    [ R.h3
                        { style: R.css { margin: "0 0 16px 0", color: "#333" }
                        , children: [ R.text $ "Node " <> show info.id ]
                        }
                    , R.div
                        { style: R.css { marginBottom: "12px" }
                        , children:
                            [ R.strong_ [ R.text "Group: " ]
                            , R.span
                                { style: R.css
                                    { color: case info.group of
                                        0 -> "#1f77b4"
                                        1 -> "#ff7f0e"
                                        2 -> "#2ca02c"
                                        _ -> "#d62728"
                                    }
                                , children: [ R.text info.groupName ]
                                }
                            ]
                        }
                    , R.div
                        { style: R.css { marginBottom: "16px" }
                        , children:
                            [ R.strong_ [ R.text "Importance: " ]
                            , R.text $ show (roundTo2 info.importance)
                            ]
                        }
                    , R.button
                        { onClick: capture_ $ setSelectedNode \_ -> Nothing
                        , style: R.css
                            { padding: "8px 16px"
                            , background: "#666"
                            , color: "white"
                            , border: "none"
                            , borderRadius: "4px"
                            , cursor: "pointer"
                            , width: "100%"
                            }
                        , children: [ R.text "Close" ]
                        }
                    ]
                }
          -- Backdrop for modal
          , case selectedNode of
              Nothing -> R.text ""
              Just _ -> R.div
                { onClick: capture_ $ setSelectedNode \_ -> Nothing
                , style: R.css
                    { position: "fixed"
                    , top: "0"
                    , left: "0"
                    , right: "0"
                    , bottom: "0"
                    , background: "rgba(0,0,0,0.5)"
                    , zIndex: "999"
                    }
                }

          -- Visualization container
          , R.div
              { id: containerId
              , style: R.css
                  { width: "800px"
                  , height: "600px"
                  , border: "1px solid #ddd"
                  , borderRadius: "8px"
                  , background: "#fafafa"
                  }
              }

          -- Legend
          , R.div
              { style: R.css
                  { display: "flex"
                  , gap: "20px"
                  , marginTop: "15px"
                  }
              , children:
                  [ legendItem "#1f77b4" "Research"
                  , legendItem "#ff7f0e" "Industry"
                  , legendItem "#2ca02c" "Government"
                  , legendItem "#d62728" "Community"
                  ]
              }
          ]
      }

-- | Legend item helper
legendItem :: String -> String -> React.JSX
legendItem color label =
  R.div
    { style: R.css { display: "flex", alignItems: "center", gap: "6px" }
    , children:
        [ R.div
            { style: R.css
                { width: "12px"
                , height: "12px"
                , borderRadius: "50%"
                , background: color
                }
            }
        , R.span_ [ R.text label ]
        ]
    }

-- | Round number to 2 decimal places
roundTo2 :: Number -> Number
roundTo2 n = toNumber (unsafeRound (n * 100.0)) / 100.0

-- Unsafe round for FFI
foreign import unsafeRound :: Number -> Int

-- | Cosine function
foreign import cos :: Number -> Number

-- | Sine function
foreign import sin :: Number -> Number
