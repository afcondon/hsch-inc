-- | PSD3.React.Simulation - Force simulation integration for React
-- |
-- | This module provides React hooks for integrating PSD3 force simulations
-- | with React components, matching the subscription pattern used in Halogen.
-- |
-- | ## Architecture
-- |
-- | Like Halogen integration, React state owns the simulation lifecycle:
-- | - Simulation handle stored in React ref (created once)
-- | - Tick events trigger re-renders via state updates
-- | - Setup changes applied declaratively
-- |
-- | ## Usage
-- |
-- | ```purescript
-- | import Hylograph.React.Simulation (useSimulation, UseSimulationResult)
-- | import Hylograph.ForceEngine.Setup as Setup
-- |
-- | mySetup = Setup.setup "physics"
-- |   [ Setup.manyBody "charge" # Setup.withStrength (Setup.static (-100.0))
-- |   , Setup.link "links" # Setup.withDistance (Setup.static 30.0)
-- |   ]
-- |
-- | mkForceGraph :: Component { nodes :: Array SimNode, links :: Array SimLink }
-- | mkForceGraph = do
-- |   containerId <- useContainerId
-- |
-- |   component "ForceGraph" \props -> React.do
-- |     { simulation, currentNodes, isRunning } <-
-- |       useSimulation mySetup props.nodes props.links
-- |
-- |     useEffect currentNodes do
-- |       renderGraph containerId currentNodes
-- |       pure mempty
-- |
-- |     pure $ R.div { id: containerId }
-- | ```
module PSD3.React.Simulation
  ( -- * Hooks
    useSimulation
  , useSimulationWithCallbacks
  , UseSimulation(..)
    -- * Types
  , UseSimulationResult
  , SimulationCallbackHandlers
  , defaultCallbackHandlers
    -- * Re-exports for convenience
  , module Sim
  , module Setup
  , module Events
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Ref as Ref
import Hylograph.ForceEngine.Simulation (Simulation, SimulationNode, defaultConfig, createWithCallbacks, setNodes, setLinks, start, stop, reheat, getNodes) as Sim
import Hylograph.ForceEngine.Setup (Setup, applySetup, applySetupWithData) as Setup
import Hylograph.ForceEngine.Events (SimulationEvent(..), SimulationCallbacks, defaultCallbacks) as Events
import Data.Array as Array
import React.Basic.Hooks (Hook, UseEffect, UseState, UseRef, coerceHook, useState, useEffect, useEffectOnce)
import React.Basic.Hooks as React

-- =============================================================================
-- Types
-- =============================================================================

-- | Result of useSimulation hook
type UseSimulationResult row linkRow =
  { simulation :: Maybe (Sim.Simulation row linkRow)
  , currentNodes :: Array (Sim.SimulationNode row)
  , isRunning :: Boolean
  , alpha :: Number
  , tickCount :: Int  -- Use this as useEffect dependency for rendering
  }

-- | Callback handlers that React components can provide
-- | These are called in response to simulation events
type SimulationCallbackHandlers =
  { onTick :: Effect Unit
  , onStart :: Effect Unit
  , onStop :: Effect Unit
  , onAlphaThreshold :: Number -> Effect Unit
  }

-- | Default no-op callback handlers
defaultCallbackHandlers :: SimulationCallbackHandlers
defaultCallbackHandlers =
  { onTick: pure unit
  , onStart: pure unit
  , onStop: pure unit
  , onAlphaThreshold: \_ -> pure unit
  }

-- =============================================================================
-- Hook Type (wraps the composition of primitive hooks)
-- =============================================================================

-- | Internal hook type representing the composition of hooks used.
-- | The type parameters track the node/link types and the hook chain.
newtype UseSimulation row linkRow hooks = UseSimulation
  ( UseEffect { nodeCount :: Int, linkCount :: Int }
      ( UseEffect Unit
          ( UseRef (Maybe (Sim.Simulation row linkRow))
              ( UseState (Maybe (Sim.Simulation row linkRow))
                  ( UseState Number
                      ( UseState Boolean
                          ( UseState Int  -- tickCount
                              ( UseState (Array (Sim.SimulationNode row)) hooks))))))))

derive instance newtypeUseSimulation :: Newtype (UseSimulation row linkRow hooks) _

-- =============================================================================
-- Main Hook
-- =============================================================================

-- | Hook for managing a force simulation in React.
-- |
-- | This hook:
-- | - Creates the simulation on mount
-- | - Applies the setup configuration
-- | - Sets nodes and links
-- | - Updates state on each tick (triggering re-renders)
-- | - Cleans up on unmount
-- |
-- | Usage:
-- | ```purescript
-- | mkForceGraph :: Component Props
-- | mkForceGraph = do
-- |   containerId <- useContainerId
-- |   component "ForceGraph" \props -> React.do
-- |     { simulation, currentNodes, isRunning } <-
-- |       useSimulation mySetup props.nodes props.links
-- |
-- |     -- Render using currentNodes (updates on each tick)
-- |     useEffect currentNodes do
-- |       renderGraph containerId currentNodes
-- |       pure mempty
-- |
-- |     pure $ R.div { id: containerId }
-- | ```
useSimulation
  :: forall row linkRow
   . Setup.Setup (Sim.SimulationNode row)
  -> Array (Sim.SimulationNode row)
  -> Array { source :: Int, target :: Int | linkRow }
  -> Hook (UseSimulation row linkRow) (UseSimulationResult row linkRow)
useSimulation setup nodes links =
  useSimulationWithCallbacks setup nodes links defaultCallbackHandlers

-- | Hook with custom callback handlers.
-- |
-- | Use this when you need to respond to specific simulation events:
-- | ```purescript
-- | let handlers =
-- |       { onTick: log "tick"
-- |       , onStart: setStatus "Running..."
-- |       , onStop: setStatus "Settled"
-- |       , onAlphaThreshold: \a -> when (a < 0.1) $ log "Almost settled"
-- |       }
-- | result <- useSimulationWithCallbacks setup nodes links handlers
-- | ```
useSimulationWithCallbacks
  :: forall row linkRow
   . Setup.Setup (Sim.SimulationNode row)
  -> Array (Sim.SimulationNode row)
  -> Array { source :: Int, target :: Int | linkRow }
  -> SimulationCallbackHandlers
  -> Hook (UseSimulation row linkRow) (UseSimulationResult row linkRow)
useSimulationWithCallbacks setup nodes links handlers = coerceHook React.do
  -- State for current node positions (triggers re-render on tick)
  currentNodes /\ setCurrentNodes <- useState nodes
  ticks /\ setTicks <- useState 0  -- Tick counter for useEffect dependency
  running /\ setRunning <- useState false
  alpha /\ setAlpha <- useState 1.0
  -- Track simulation handle in state so we can return it
  simHandle /\ setSimHandle <- useState (Nothing :: Maybe (Sim.Simulation row linkRow))

  -- Ref for simulation handle (used in callbacks, doesn't cause re-render)
  simRef <- React.useRef Nothing

  -- Initialize simulation on mount
  useEffectOnce do
    -- Create callbacks that update React state
    callbacks <- Events.defaultCallbacks

    -- Wire tick callback to update node positions
    -- IMPORTANT: We increment tickCount on each tick. This is used as the
    -- useEffect dependency in consuming components. We can't rely on array
    -- equality because PureScript's Eq for arrays compares contents, and D3
    -- mutates node objects in place (same references, changed values).
    Ref.write (do
      mSim <- React.readRef simRef
      case mSim of
        Nothing -> pure unit
        Just sim -> do
          ns <- Sim.getNodes sim
          setCurrentNodes \_ -> ns
          setTicks \n -> n + 1  -- Increment tick counter for useEffect dependency
          handlers.onTick
    ) callbacks.onTick

    -- Wire start callback
    Ref.write (do
      setRunning \_ -> true
      handlers.onStart
    ) callbacks.onStart

    -- Wire stop callback
    Ref.write (do
      setRunning \_ -> false
      handlers.onStop
    ) callbacks.onStop

    -- Wire alpha threshold callback
    Ref.write (\a -> do
      setAlpha \_ -> a
      handlers.onAlphaThreshold a
    ) callbacks.onAlphaThreshold

    -- Create simulation
    sim <- Sim.createWithCallbacks Sim.defaultConfig callbacks

    -- Store in ref (for callbacks) and state (for return value)
    React.writeRef simRef (Just sim)
    setSimHandle \_ -> Just sim

    -- Apply setup and initial data
    Setup.applySetup setup sim
    Sim.setNodes nodes sim
    Sim.setLinks links sim

    -- Start simulation
    Sim.start sim

    -- Cleanup on unmount
    pure do
      mSim <- React.readRef simRef
      case mSim of
        Nothing -> pure unit
        Just s -> Sim.stop s

  -- Update nodes/links when props change
  -- Use array lengths as a simple change detection key (has Eq instance)
  let dataKey = { nodeCount: Array.length nodes, linkCount: Array.length links }
  useEffect dataKey do
    mSim <- React.readRef simRef
    case mSim of
      Nothing -> pure mempty
      Just sim -> do
        -- Apply new data with GUP semantics
        _ <- Setup.applySetupWithData setup nodes links sim
        Sim.reheat sim
        pure mempty

  -- Return current state
  pure
    { simulation: simHandle
    , currentNodes
    , isRunning: running
    , alpha
    , tickCount: ticks
    }
