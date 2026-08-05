-- | Entry point — installs `window.PolyglotWash`, the seam between the
-- | film's JS timeline and the Hylograph wash layer.
-- |
-- |   PolyglotWash.paintBeat(beat, staggerMs)  render beat's washes, paint-on
-- |   PolyglotWash.tick(deltaMs)               advance active reveals
-- |   PolyglotWash.reset()                     clear every wash container
-- |   PolyglotWash.beats                       beats that own washes
-- |
-- | There is deliberately NO timer in here: the film owns the one timer
-- | (a setInterval, never requestAnimationFrame) and pushes deltas in, so
-- | rehearsal speed and seeking stay coherent across copy, camera and wash.
-- |
-- | Two traps this module exists to encode (each cost a debugging session):
-- |   - `rerender` takes a CSS SELECTOR — the `#` is added in exactly one
-- |     place, `container` below.
-- |   - clearing is `clearContainer`, never a rerender of an empty tree:
-- |     plain `elem` children are positional, so an empty child list has no
-- |     exit phase and leaves everything in place.
module Wash.Main
  ( main
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Console (log)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, mkEffectFn2)
import Hylograph.HATS.InterpreterTick (clearContainer, rerender) as HATS
import Hylograph.HATS.Transitions (HATSTransitions, TransitionResult(..), tickTransitions)
import Wash.Paint (beatTree)
import Wash.Specs (specs)

type Api =
  { paintBeat :: EffectFn2 Int Number Unit
  , tick :: EffectFn1 Number Unit
  , reset :: Effect Unit
  , beats :: Array Int
  }

foreign import install :: Api -> Effect Unit

type Active = Ref.Ref (Array HATSTransitions)

main :: Effect Unit
main = do
  active <- Ref.new []
  install
    { paintBeat: mkEffectFn2 (paintBeat active)
    , tick: mkEffectFn1 (tick active)
    , reset: reset active
    , beats: washBeats
    }
  log "[wash] PolyglotWash installed — real hylograph-onion, not the study's inline copy"

washBeats :: Array Int
washBeats = Array.nub (map _.beat specs)

-- | The one place the `#` is added (rerender wants a selector, not an id).
container :: Int -> String
container beat = "#washB" <> show beat

paintBeat :: Active -> Int -> Number -> Effect Unit
paintBeat active beat staggerMs = case beatTree staggerMs beat of
  Nothing -> pure unit
  Just tree -> do
    -- Clear first so a re-run is an ENTER, not an update with no phase.
    HATS.clearContainer (container beat)
    result <- HATS.rerender (container beat) tree
    case result.transitions of
      Nothing -> pure unit
      Just ts -> Ref.modify_ (flip Array.snoc ts) active

tick :: Active -> Number -> Effect Unit
tick active delta = do
  running <- Ref.read active
  unless (Array.null running) do
    stepped <- traverse step running
    Ref.write (Array.catMaybes stepped) active
  where
  step :: HATSTransitions -> Effect (Maybe HATSTransitions)
  step ts = do
    res <- tickTransitions delta ts
    pure case res of
      Complete -> Nothing
      Running next -> Just next

reset :: Active -> Effect Unit
reset active = do
  Ref.write [] active
  for_ washBeats \beat -> HATS.clearContainer (container beat)
