-- | The wash spec table for video 0 — the design data that used to live
-- | inline in `composition-study.html`. One place, one shape.
-- |
-- | Every wash is assigned to a beat; the film's timeline asks for a beat's
-- | washes when that beat's camera comes to rest (or, for the cascade, when
-- | the turn begins). Two pseudo-beats extend the 1..15 numbering:
-- |
-- |   80 — the cascade (seed 19): paints at the START of beat 8, while the
-- |        camera is still dropping through the east turn. The turn is the
-- |        event; the cascade is what the event looks like.
-- |   16 — the poster washes: paint as the closing dissolve begins.
module Wash.Specs
  ( Hue(..)
  , hueHex
  , WashSpec
  , specs
  ) where

import Prelude

import Data.Maybe (Maybe(..))

-- | The colour law, as a closed set. Prussian is the argument; ochre the
-- | price; the five runtime hues appear only at the fan, the chips, and the
-- | poster ribbons.
data Hue = Prussian | Ochre | Js | Beam | Julia | Go | Py

hueHex :: Hue -> String
hueHex = case _ of
  Prussian -> "#254a6f"
  Ochre -> "#b3831c"
  Js -> "#c05b2a"
  Beam -> "#872e3c"
  Julia -> "#6f568f"
  Go -> "#2e6f6a"
  Py -> "#4f6d2e"

type WashSpec =
  { seed :: Int          -- study seed; PRNG seed is 1969 + seed * 7919
  , x :: Number          -- group translate, stage coordinates
  , y :: Number
  , rx :: Number         -- base ellipse radii
  , ry :: Number
  , hue :: Hue
  , layers :: Int        -- variants to stack (study `n`, default 14)
  , depth :: Int         -- subdivision depth (study `dep`, default 5)
  , opacity :: Number    -- per-layer fill-opacity (study `lo`, default .045)
  , clampLo :: Maybe Number  -- clamp base-poly x >= this (local coords)
  , clampHi :: Maybe Number  -- clamp base-poly x <= this (local coords)
  , clip :: Maybe String     -- clipPath id in the film's SVG defs
  , beat :: Int
  }

wash :: WashSpec
wash =
  { seed: 0, x: 0.0, y: 0.0, rx: 0.0, ry: 0.0
  , hue: Prussian, layers: 14, depth: 5, opacity: 0.045
  , clampLo: Nothing, clampHi: Nothing, clip: Nothing
  , beat: 0
  }

-- | The table, verbatim from the signed-off study (round 4), plus beat
-- | assignments. Coordinates and parameters are layout — do not retune here;
-- | retiming lives in the film's `T` table.
specs :: Array WashSpec
specs =
  -- ------------------------------------------------------------ pass 1
  [ wash { seed = 11, x = 430.0,  y = 540.0, rx = 150.0, ry = 100.0, layers = 16, beat = 1 }  -- beat 1 bloom
  , wash { seed = 12, x = 1240.0, y = 545.0, rx = 55.0,  ry = 38.0,  layers = 10, depth = 4, beat = 2 }
  , wash { seed = 13, x = 2255.0, y = 562.0, rx = 50.0,  ry = 34.0,  layers = 10, depth = 4, beat = 3 }  -- in the dip
  , wash { seed = 14, x = 3060.0, y = 538.0, rx = 55.0,  ry = 38.0,  layers = 10, depth = 4, beat = 4 }
  , wash { seed = 15, x = 4200.0, y = 542.0, rx = 50.0,  ry = 36.0,  layers = 10, depth = 4, beat = 5 }
  , wash { seed = 35, x = 3810.0, y = 905.0, rx = 95.0,  ry = 40.0,  hue = Ochre, layers = 10, depth = 4, opacity = 0.04, beat = 5 }  -- the cost
  , wash { seed = 16, x = 4825.0, y = 600.0, rx = 120.0, ry = 210.0, layers = 26, opacity = 0.05
         , clampHi = Just 55.0, clip = Just "clipWallW", beat = 6 }  -- the pool
  , wash { seed = 17, x = 6100.0, y = 520.0, rx = 480.0, ry = 130.0, layers = 24, opacity = 0.05, beat = 7 }  -- the FLOOD
  , wash { seed = 18, x = 6900.0, y = 530.0, rx = 260.0, ry = 90.0,  layers = 16, beat = 7 }
  -- ------------------------------------------------------- the east turn
  , wash { seed = 19, x = 7480.0, y = 1100.0, rx = 100.0, ry = 280.0, layers = 16, beat = 80 }  -- cascade
  -- ------------------------------------------------------------ pass 2
  , wash { seed = 20, x = 7440.0, y = 1630.0, rx = 90.0, ry = 40.0, layers = 12, depth = 4, beat = 8 }  -- landing
  , wash { seed = 21, x = 6960.0, y = 1616.0, rx = 55.0, ry = 36.0, layers = 10, depth = 4, beat = 8 }
  , wash { seed = 38, x = 4900.0, y = 1618.0, rx = 50.0, ry = 34.0, layers = 10, depth = 4, beat = 10 }
  , wash { seed = 39, x = 4300.0, y = 1616.0, rx = 45.0, ry = 32.0, layers = 10, depth = 4, beat = 10 }
  , wash { seed = 40, x = 3860.0, y = 1410.0, rx = 170.0, ry = 120.0, layers = 14, opacity = 0.04, beat = 10 }  -- misfit
  , wash { seed = 22, x = 1140.0, y = 1616.0, rx = 45.0, ry = 32.0, layers = 10, depth = 4, beat = 12 }
  , wash { seed = 23, x = 2560.0, y = 1730.0, rx = 42.0, ry = 26.0, hue = Py,    layers = 10, depth = 4, beat = 11 }  -- fan blooms
  , wash { seed = 24, x = 2560.0, y = 1810.0, rx = 42.0, ry = 26.0, hue = Go,    layers = 10, depth = 4, beat = 11 }
  , wash { seed = 25, x = 2560.0, y = 1890.0, rx = 42.0, ry = 26.0, hue = Julia, layers = 10, depth = 4, beat = 11 }
  , wash { seed = 26, x = 2560.0, y = 1970.0, rx = 42.0, ry = 26.0, hue = Beam,  layers = 10, depth = 4, beat = 11 }
  , wash { seed = 27, x = 2560.0, y = 2050.0, rx = 42.0, ry = 26.0, hue = Js,    layers = 10, depth = 4, beat = 11 }
  -- ------------------------------------------------------------ pass 3
  , wash { seed = 29, x = 660.0, y = 2483.0, rx = 65.0, ry = 30.0, hue = Js,    layers = 10, depth = 4, opacity = 0.05, beat = 13 }
  , wash { seed = 30, x = 660.0, y = 2578.0, rx = 65.0, ry = 30.0, hue = Beam,  layers = 10, depth = 4, opacity = 0.05, beat = 13 }
  , wash { seed = 31, x = 660.0, y = 2673.0, rx = 65.0, ry = 30.0, hue = Julia, layers = 10, depth = 4, opacity = 0.05, beat = 13 }
  , wash { seed = 32, x = 660.0, y = 2768.0, rx = 65.0, ry = 30.0, hue = Go,    layers = 10, depth = 4, opacity = 0.05, beat = 13 }
  , wash { seed = 33, x = 660.0, y = 2863.0, rx = 65.0, ry = 30.0, hue = Py,    layers = 10, depth = 4, opacity = 0.05, beat = 13 }
  , wash { seed = 34, x = 2100.0, y = 2945.0, rx = 50.0, ry = 34.0, layers = 10, depth = 4, beat = 13 }
  , wash { seed = 36, x = 4460.0, y = 2952.0, rx = 50.0, ry = 34.0, layers = 10, depth = 4, beat = 14 }
  , wash { seed = 37, x = 6580.0, y = 3060.0, rx = 640.0, ry = 170.0, layers = 26, opacity = 0.04, beat = 15 }  -- title
  -- ---------------------------------------------------------- the poster
  , wash { seed = 41, x = 330.0,  y = 520.0, rx = 200.0, ry = 250.0, layers = 22, beat = 16 }  -- the mass
  , wash { seed = 42, x = 470.0,  y = 560.0, rx = 130.0, ry = 310.0, layers = 22, opacity = 0.055
         , clampHi = Just 48.0, clip = Just "clipWallP", beat = 16 }  -- the bank
  , wash { seed = 43, x = 800.0,  y = 530.0, rx = 250.0, ry = 110.0, layers = 20, opacity = 0.05
         , clampLo = Just (-210.0), beat = 16 }  -- flood
  , wash { seed = 44, x = 1060.0, y = 520.0, rx = 170.0, ry = 80.0,  layers = 14, beat = 16 }
  ]
