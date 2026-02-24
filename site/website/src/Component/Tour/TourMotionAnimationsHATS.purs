-- | HATS version of TourMotionAnimations
-- |
-- | Migrated from imperative stored-selection pattern to declarative HATS.
-- | Key changes:
-- | - No stored selections - re-render with new state instead
-- | - GUP via forEachWithGUP with PhaseSpec transitions
-- | - Animation by updating data and re-rendering
module Component.Tour.TourMotionAnimationsHATS
  ( -- SVG management
    renderViz
  , clearViz
    -- Data types
  , VizState(..)
  , StepData(..)
  , CircleData
  , MultiCircleData
  , GUPCircleData
  , LetterData
    -- Step-specific renderers
  , buildStep1Tree
  , buildStep2Tree
  , buildStep3Tree
  , buildStep4Tree
  , buildStep5Tree
  , buildStep6Tree
    -- Data generators
  , makeMultiCircleData
  , gupAllCircles
  , leftX
  , rightX
  , centerY
  ) where

import Prelude

import Data.Array (range, filter, mapWithIndex)
import Data.Array as Array
import Data.String.CodeUnits as SCU
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Effect (Effect)
import Hylograph.HATS (Tree, elem, forEach, forEachWithGUP, GUPSpec, PhaseSpec, staticStr, staticNum)
import Hylograph.HATS.Friendly as F
import Hylograph.HATS.InterpreterTick (rerender, clearContainer) as HATS
import Hylograph.Internal.Selection.Types (ElementType(..))
import Hylograph.Internal.Transition.Types (transitionWith, Easing(..)) as Transition

-- =============================================================================
-- Data Types
-- =============================================================================

-- | Single circle data
type CircleData = { id :: Int, x :: Number, y :: Number, opacity :: Number }

-- | Multi-circle data
type MultiCircleData = { id :: Int, x :: Number }

-- | GUP circle data
type GUPCircleData = { id :: Int, x :: Number }

-- | Letter data
type LetterData = { letter :: String, index :: Int }

-- | Current state for visualization
data StepData
  = Step1Data CircleData                    -- Single circle with opacity
  | Step2Data CircleData                    -- Single circle with position
  | Step3Data (Array MultiCircleData) Number  -- Multiple circles, target Y
  | Step4Data (Array MultiCircleData) Number  -- Multiple circles (staggered), target Y
  | Step5Data (Array Int)                   -- GUP circles - visible IDs
  | Step6Data String                        -- GUP letters - current string
  | EmptyData                               -- Clear/transition states

-- | Viz state tracks what's currently rendered
newtype VizState = VizState
  { selector :: String
  , currentStep :: Int
  }

-- =============================================================================
-- Constants
-- =============================================================================

svgWidth :: Number
svgWidth = 500.0

svgHeight :: Number
svgHeight = 300.0

centerY :: Number
centerY = 150.0

leftX :: Number
leftX = 100.0

rightX :: Number
rightX = 400.0

circleRadius :: Number
circleRadius = 30.0

-- =============================================================================
-- SVG Container (shared across all steps)
-- =============================================================================

-- | Build the outer SVG container with child content
buildSvgContainer :: Array Tree -> Tree
buildSvgContainer children =
  elem SVG
    [ F.width svgWidth
    , F.height svgHeight
    , F.viewBox 0.0 0.0 svgWidth svgHeight
    , F.class_ "motion-scrolly-viz"
    , F.preserveAspectRatio "xMidYMid meet"
    ]
    [ elem Group
        [ F.class_ "circles-group" ]
        children
    ]

-- =============================================================================
-- Step 1: Single Circle (Breathing - opacity animation)
-- =============================================================================

buildStep1Tree :: CircleData -> Tree
buildStep1Tree circle =
  buildSvgContainer
    [ forEachWithGUP "circle" Circle [circle] (show <<< _.id)
        (\d -> elem Circle
          [ F.cx d.x
          , F.cy d.y
          , F.r circleRadius
          , F.fill "steelblue"
          , F.opacity (show d.opacity)
          , F.class_ "main-circle"
          ]
          []
        )
        step1GupSpec
    ]

step1GupSpec :: GUPSpec CircleData
step1GupSpec =
  { enter: Just
      { attrs: [ staticNum "opacity" 0.0, staticNum "r" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 500.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicOut
          }
      }
  , update: Just
      { attrs: []  -- Template has the target values
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 1000.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.SinInOut
          }
      }
  , exit: Just
      { attrs: [ staticNum "opacity" 0.0, staticNum "r" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 300.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicIn
          }
      }
  }

-- =============================================================================
-- Step 2: Single Circle (Moving - position animation)
-- =============================================================================

buildStep2Tree :: CircleData -> Tree
buildStep2Tree circle =
  buildSvgContainer
    [ forEachWithGUP "circle" Circle [circle] (show <<< _.id)
        (\d -> elem Circle
          [ F.cx d.x
          , F.cy d.y
          , F.r circleRadius
          , F.fill "#1abc9c"  -- Teal for motion step
          , F.opacity "1"
          , F.class_ "main-circle"
          ]
          []
        )
        step2GupSpec
    ]

step2GupSpec :: GUPSpec CircleData
step2GupSpec =
  { enter: Just
      { attrs: [ staticNum "opacity" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 500.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Nothing
          }
      }
  , update: Just
      { attrs: []
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 1200.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicInOut
          }
      }
  , exit: Just
      { attrs: [ staticNum "opacity" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 300.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Nothing
          }
      }
  }

-- =============================================================================
-- Step 3: Multiple Circles (Lockstep Y movement)
-- =============================================================================

buildStep3Tree :: Array MultiCircleData -> Number -> Tree
buildStep3Tree circles targetY =
  buildSvgContainer
    [ forEachWithGUP "circles" Circle circles (show <<< _.id)
        (\d -> elem Circle
          [ F.cx d.x
          , F.cy targetY
          , F.r 25.0
          , F.fill "#e67e22"  -- Coral/orange
          , F.opacity "1"
          , F.class_ "data-circle"
          ]
          []
        )
        step3GupSpec
    ]

step3GupSpec :: GUPSpec MultiCircleData
step3GupSpec =
  { enter: Just
      { attrs:
          [ staticNum "cx" leftX  -- Spawn from single circle position
          , staticNum "r" 30.0
          , staticNum "opacity" 0.5
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 800.0
          , delay: Nothing
          , staggerDelay: Just 80.0  -- Staggered spawn
          , easing: Just Transition.CubicOut
          }
      }
  , update: Just
      { attrs: []
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 800.0
          , delay: Nothing
          , staggerDelay: Nothing  -- Lockstep for step 3
          , easing: Just Transition.SinInOut
          }
      }
  , exit: Just
      { attrs: [ staticNum "opacity" 0.0, staticNum "r" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 400.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicIn
          }
      }
  }

-- =============================================================================
-- Step 4: Multiple Circles (Staggered Y movement - wave)
-- =============================================================================

buildStep4Tree :: Array MultiCircleData -> Number -> Tree
buildStep4Tree circles targetY =
  buildSvgContainer
    [ forEachWithGUP "circles" Circle circles (show <<< _.id)
        (\d -> elem Circle
          [ F.cx d.x
          , F.cy targetY
          , F.r 25.0
          , F.fill "#9b59b6"  -- Purple for staggered
          , F.opacity "1"
          , F.class_ "data-circle"
          ]
          []
        )
        step4GupSpec
    ]

step4GupSpec :: GUPSpec MultiCircleData
step4GupSpec =
  { enter: Just
      { attrs:
          [ staticNum "cx" leftX
          , staticNum "r" 30.0
          , staticNum "opacity" 0.5
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 800.0
          , delay: Nothing
          , staggerDelay: Just 80.0
          , easing: Just Transition.CubicOut
          }
      }
  , update: Just
      { attrs: []
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 600.0
          , delay: Nothing
          , staggerDelay: Just 80.0  -- STAGGERED for wave effect!
          , easing: Just Transition.SinInOut
          }
      }
  , exit: Just
      { attrs: [ staticNum "opacity" 0.0, staticNum "r" 0.0 ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 400.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicIn
          }
      }
  }

-- =============================================================================
-- Step 5: GUP Circles (Enter/Update/Exit demo)
-- =============================================================================

-- | Generate multi-circle data for steps 3-4
makeMultiCircleData :: Int -> Array MultiCircleData
makeMultiCircleData numCircles =
  let spacing = 60.0
      startX = 80.0
  in range 0 (numCircles - 1) <#> \i ->
       { id: i + 100  -- Different IDs from single circle
       , x: startX + toNumber i * spacing
       }

-- | All possible circle positions for GUP demo
gupAllCircles :: Array GUPCircleData
gupAllCircles =
  let numCircles = 7
      spacing = 55.0
      startX = 60.0
  in range 0 (numCircles - 1) <#> \i ->
       { id: i, x: startX + toNumber i * spacing }

buildStep5Tree :: Array Int -> Tree
buildStep5Tree visibleIds =
  let visibleCircles = gupAllCircles # filter (\c -> Array.elem c.id visibleIds)
  in buildSvgContainer
    [ forEachWithGUP "gup-circles" Circle visibleCircles (show <<< _.id)
        (\d -> elem Circle
          [ F.cx d.x
          , F.cy centerY
          , F.r 25.0
          , F.fill "#7f8c8d"  -- Gray (final state)
          , F.opacity "1"
          , F.class_ "gup-circle"
          ]
          []
        )
        step5GupSpec
    ]

step5GupSpec :: GUPSpec GUPCircleData
step5GupSpec =
  { enter: Just
      { attrs:
          [ staticNum "r" 40.0           -- Start large
          , staticStr "fill" "#27ae60"   -- Green for entering
          , staticNum "opacity" 1.0
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 800.0
          , delay: Nothing
          , staggerDelay: Just 60.0
          , easing: Just Transition.CubicInOut
          }
      }
  , update: Just
      { attrs:
          [ staticNum "r" 25.0           -- Normal size
          , staticStr "fill" "#7f8c8d"   -- Gray
          , staticNum "opacity" 1.0
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 400.0
          , delay: Nothing
          , staggerDelay: Nothing
          , easing: Just Transition.CubicInOut
          }
      }
  , exit: Just
      { attrs:
          [ staticNum "r" 0.0            -- Shrink
          , staticStr "fill" "#a04000"   -- Brown for exiting
          , staticNum "opacity" 0.0
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 400.0
          , delay: Nothing
          , staggerDelay: Just 40.0
          , easing: Just Transition.CubicIn
          }
      }
  }

-- =============================================================================
-- Step 6: GUP Letters
-- =============================================================================

buildStep6Tree :: String -> Tree
buildStep6Tree letterString =
  let letters = mapWithIndex (\i c -> { letter: SCU.singleton c, index: i })
                  (SCU.toCharArray letterString)
      letterSpacing = 50.0
      letterStartX = 60.0
  in buildSvgContainer
    [ forEachWithGUP "gup-letters" Text letters _.letter
        (\d -> elem Text
          [ F.x (letterStartX + toNumber d.index * letterSpacing)
          , F.y centerY
          , F.fontSize "36px"
          , F.textAnchor "middle"
          , F.attr "dominant-baseline" "middle"
          , F.fill "#2c3e50"  -- Dark (final state)
          , F.opacity "1"
          , F.attr "textContent" d.letter
          ]
          []
        )
        step6GupSpec
    ]

step6GupSpec :: GUPSpec LetterData
step6GupSpec =
  { enter: Just
      { attrs:
          [ staticNum "y" 50.0           -- Start above
          , staticNum "opacity" 0.0
          , staticStr "fill" "#27ae60"   -- Green
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 750.0
          , delay: Nothing
          , staggerDelay: Just 50.0
          , easing: Just Transition.BounceOut
          }
      }
  , update: Just
      { attrs:
          [ staticNum "y" centerY
          , staticStr "fill" "#2c3e50"   -- Dark
          , staticNum "opacity" 1.0
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 500.0
          , delay: Nothing
          , staggerDelay: Just 30.0
          , easing: Just Transition.CubicInOut
          }
      }
  , exit: Just
      { attrs:
          [ staticNum "y" 250.0          -- Drop down
          , staticNum "opacity" 0.0
          , staticStr "fill" "#e74c3c"   -- Red
          ]
      , transition: Just $ Transition.transitionWith
          { duration: Milliseconds 500.0
          , delay: Nothing
          , staggerDelay: Just 40.0
          , easing: Just Transition.CubicIn
          }
      }
  }

-- =============================================================================
-- Render/Clear Helpers
-- =============================================================================

-- | Initial render to a selector
renderViz :: String -> Tree -> Effect Unit
renderViz selector tree = do
  _ <- HATS.rerender selector tree
  pure unit

-- | Clear visualization (remove all children)
clearViz :: String -> Effect Unit
clearViz selector = HATS.clearContainer selector
