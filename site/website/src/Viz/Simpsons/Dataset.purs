-- | Simpson's Paradox Dataset Types
-- |
-- | Defines the structure for any Simpson's Paradox dataset,
-- | enabling reusable visualization components.
module D3.Viz.Simpsons.Dataset where

import Prelude

-- | A Simpson's Paradox dataset
-- |
-- | The data structure captures a 2x2 contingency table with two subgroups (rows)
-- | and two comparison groups (columns). The paradox emerges when comparing
-- | per-subgroup rates vs. combined rates.
type Dataset =
  { id :: String              -- ^ Short identifier (e.g., "berkeley")
  , title :: String           -- ^ Display title
  , description :: String     -- ^ Explanation of the dataset
  , source :: String          -- ^ Citation/source

  -- Row labels (the lurking variable / subgroups)
  , row1Label :: String       -- ^ First subgroup (e.g., "Easier majors")
  , row2Label :: String       -- ^ Second subgroup (e.g., "Harder majors")
  , combinedLabel :: String   -- ^ Label for combined row (usually "Combined")

  -- Column group labels (what's being measured)
  , colGroupLabels :: { count :: String, outcome :: String, percent :: String }
  -- e.g., { count: "# Applied", outcome: "# Admitted", percent: "% Admitted" }

  -- Column labels (the comparison groups)
  , colALabel :: String       -- ^ First comparison group (e.g., "Women")
  , colBLabel :: String       -- ^ Second comparison group (e.g., "Men")

  -- Actual data: row1 and row2 each have [countA, countB, outcomeA, outcomeB]
  , row1 :: { countA :: Number, countB :: Number, outcomeA :: Number, outcomeB :: Number }
  , row2 :: { countA :: Number, countB :: Number, outcomeA :: Number, outcomeB :: Number }

  -- Axis labels for the plot
  , axisLabels :: { x :: String, y :: String }

  -- Initial slider positions (percentage in row2 for each group)
  , initialLv :: { a :: Number, b :: Number }
  }

-- | Derived statistics from a dataset
type DerivedStats =
  { row1PercentA :: Number
  , row1PercentB :: Number
  , row2PercentA :: Number
  , row2PercentB :: Number
  , combinedCountA :: Number
  , combinedCountB :: Number
  , combinedOutcomeA :: Number
  , combinedOutcomeB :: Number
  , combinedPercentA :: Number
  , combinedPercentB :: Number
  , isParadox :: Boolean      -- ^ True if combined reverses subgroup trends
  }

-- | Calculate derived statistics from a dataset
deriveStats :: Dataset -> DerivedStats
deriveStats d =
  let
    row1PercentA = safePercent d.row1.outcomeA d.row1.countA
    row1PercentB = safePercent d.row1.outcomeB d.row1.countB
    row2PercentA = safePercent d.row2.outcomeA d.row2.countA
    row2PercentB = safePercent d.row2.outcomeB d.row2.countB

    combinedCountA = d.row1.countA + d.row2.countA
    combinedCountB = d.row1.countB + d.row2.countB
    combinedOutcomeA = d.row1.outcomeA + d.row2.outcomeA
    combinedOutcomeB = d.row1.outcomeB + d.row2.outcomeB
    combinedPercentA = safePercent combinedOutcomeA combinedCountA
    combinedPercentB = safePercent combinedOutcomeB combinedCountB

    -- Paradox: A beats B in both subgroups but B beats A combined (or vice versa)
    aBetterInRow1 = row1PercentA > row1PercentB
    aBetterInRow2 = row2PercentA > row2PercentB
    aBetterCombined = combinedPercentA > combinedPercentB

    isParadox = (aBetterInRow1 && aBetterInRow2 && not aBetterCombined)
             || (not aBetterInRow1 && not aBetterInRow2 && aBetterCombined)
  in
    { row1PercentA, row1PercentB
    , row2PercentA, row2PercentB
    , combinedCountA, combinedCountB
    , combinedOutcomeA, combinedOutcomeB
    , combinedPercentA, combinedPercentB
    , isParadox
    }

-- | Safe percentage calculation (handles division by zero)
safePercent :: Number -> Number -> Number
safePercent numerator denominator
  | denominator == 0.0 = 0.0
  | otherwise = numerator / denominator * 100.0
