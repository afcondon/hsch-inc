-- | Wash rendering for the video-0 film, through the real library.
-- |
-- | The study's inline `wash()` reimplemented Onion.Watercolour; this module
-- | replaces it with `Onion.Watercolour.watercolourBlob` and renders each
-- | blob as a keyed HATS join whose ENTER phase carries a staggered
-- | transition — so the wash paints itself layer by layer, in deposition
-- | order. `paintOn`/`paintCurve` are lifted from
-- | `purescript-hylograph-demos/onion/src/Demo/Recipes.purs`.
module Wash.Paint
  ( beatTree
  ) where

import Prelude

import Data.Array as Array
import Data.Int (toNumber) as Int
import Data.Maybe (Maybe(..))
import Data.Number (pi, cos, sin) as Number
import Data.Time.Duration (Milliseconds(..))
import Hylograph.HATS (Tree, elem, forEachWithGUP, staticStr)
import Hylograph.HATS.Friendly as F
import Hylograph.Internal.Element.Types (ElementType(..))
import Hylograph.Transition.Types (Easing(..), TransitionConfig)
import Onion.Hats (Blob, indexedVariants, variantKey)
import Onion.PathData (pathDataClosed)
import Onion.Prng as Prng
import Onion.Watercolour as WC
import Wash.Specs (WashSpec, hueHex, specs)

-- | The study's base polygon: 12 vertices on an ellipse, each pushed in or
-- | out by a per-vertex radial jitter in [0.88, 1.12), with optional x
-- | clamping (the pool washes pile pigment against the wall's face). The
-- | noise source is Onion.Prng rather than the study's mulberry32, so the
-- | exact outlines differ from the still while the character is identical.
basePoly :: Prng.Seed -> WashSpec -> { poly :: WC.Polygon, seed :: Prng.Seed }
basePoly seed0 spec = go 0 seed0 []
  where
  clampX :: Number -> Number
  clampX x0 =
    let lo = case spec.clampLo of
               Nothing -> x0
               Just l -> max l x0
    in case spec.clampHi of
         Nothing -> lo
         Just h -> min h lo

  go :: Int -> Prng.Seed -> WC.Polygon -> { poly :: WC.Polygon, seed :: Prng.Seed }
  go i seed acc
    | i >= 12 = { poly: acc, seed }
    | otherwise =
        let a = Int.toNumber i * Number.pi / 6.0
            r = Prng.next seed
            j = 0.88 + r.value * 0.24
            pt = { x: clampX (Number.cos a * spec.rx * j)
                 , y: Number.sin a * spec.ry * j
                 }
        in go (i + 1) r.seed (Array.snoc acc pt)

-- | Pre-deform one spec into its variant stack. Pure and seeded, so the
-- | same spec gives the identical wash on every run — take one and take
-- | nine are the same film.
mkWashBlob :: WashSpec -> Blob
mkWashBlob spec =
  let seed0 = 1969 + spec.seed * 7919
      base = basePoly seed0 spec
      wc = WC.watercolourBlob
             { layers: spec.layers, depth: spec.depth, displacement: 0.15 }
             base.seed
             base.poly
  in { variants: wc.variants, opacity: spec.opacity }

-- | Pigment settles — short per-layer duration, longer stagger. Lifted from
-- | Demo.Recipes: a long duration with a short stagger reads as one shape
-- | fading up, which is the thing this whole module exists to avoid.
paintCurve :: Number -> TransitionConfig
paintCurve staggerMs =
  { duration: Milliseconds 260.0
  , delay: Nothing
  , staggerDelay: Just staggerMs
  , easing: Just SinOut
  }

-- | One wash: a positioned group holding the keyed variant join, with the
-- | enter phase staggered so the layers arrive in deposition order. The
-- | template attrs are the FINAL state; the enter attrs are the START.
washTree :: Number -> WashSpec -> Tree
washTree staggerMs spec =
  let blob = mkWashBlob spec
      joinName = "w" <> show spec.seed
      positioned =
        elem Group
          [ staticStr "transform" ("translate(" <> show spec.x <> "," <> show spec.y <> ")") ]
          [ forEachWithGUP joinName Path (indexedVariants blob.variants) variantKey
              (\v ->
                 elem Path
                   [ F.d (pathDataClosed v.poly)
                   , F.fill (hueHex spec.hue)
                   , F.fillOpacity (show blob.opacity)   -- the TO
                   , staticStr "stroke" "none"
                   ]
                   [])
              { enter: Just
                  { attrs: [ F.fillOpacity "0" ]          -- the FROM
                  , transition: Just (paintCurve staggerMs)
                  }
              , update: Nothing
              , exit: Nothing
              }
          ]
  in case spec.clip of
       Nothing -> positioned
       Just clipId ->
         elem Group [ staticStr "clip-path" ("url(#" <> clipId <> ")") ] [ positioned ]

-- | All washes for one beat, as a single tree (one rerender, one
-- | transitions handle). Nothing when the beat has no washes.
beatTree :: Number -> Int -> Maybe Tree
beatTree staggerMs beat =
  case Array.filter (\s -> s.beat == beat) specs of
    [] -> Nothing
    matching -> Just (elem Group [] (map (washTree staggerMs) matching))
