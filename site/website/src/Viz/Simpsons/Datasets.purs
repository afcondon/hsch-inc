-- | Simpson's Paradox Example Datasets
-- |
-- | Collection of classic examples demonstrating Simpson's Paradox,
-- | sourced from the USU CTIS applet by Schneiter.
module D3.Viz.Simpsons.Datasets where

import D3.Viz.Simpsons.Dataset (Dataset)

-- | All available datasets
allDatasets :: Array Dataset
allDatasets =
  [ berkeley
  , bakerKramer
  , deathPenalty
  , airlines
  , civilRights
  , smokers
  , housePets
  ]

-- | UC Berkeley Graduate Admissions (1973)
-- | The classic example from Bickel, Hammel, O'Connell (1975)
berkeley :: Dataset
berkeley =
  { id: "berkeley"
  , title: "Berkeley Admissions Data"
  , description: "Admission rates of men and women to easier and harder admittance majors at UC Berkeley."
  , source: "Bickel, Hammel, O'Connell (1975). Science."
  , row1Label: "Easier"
  , row2Label: "Harder"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Applied", outcome: "# Admitted", percent: "% Admitted" }
  , colALabel: "Women"
  , colBLabel: "Men"
  , row1: { countA: 133.0, countB: 1385.0, outcomeA: 106.0, outcomeB: 864.0 }
  , row2: { countA: 1702.0, countB: 1306.0, outcomeA: 451.0, outcomeB: 334.0 }
  , axisLabels: { x: "Percent applied to harder majors", y: "Percent admitted" }
  , initialLv: { a: 93.0, b: 49.0 }
  }

-- | Baker-Kramer Treatment Data
-- | Hypothetical medical treatment survival rates
bakerKramer :: Dataset
bakerKramer =
  { id: "baker-kramer"
  , title: "Baker-Kramer Data"
  , description: "Hypothetical data showing survival rates among men and women for treatments A and B."
  , source: "Baker and Kramer (2001)."
  , row1Label: "Men"
  , row2Label: "Women"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# in Treatment", outcome: "# Surviving", percent: "% Surviving" }
  , colALabel: "A"
  , colBLabel: "B"
  , row1: { countA: 200.0, countB: 40.0, outcomeA: 120.0, outcomeB: 20.0 }
  , row2: { countA: 100.0, countB: 260.0, outcomeA: 95.0, outcomeB: 221.0 }
  , axisLabels: { x: "Percent women", y: "Percent surviving" }
  , initialLv: { a: 33.0, b: 87.0 }
  }

-- | Florida Death Penalty Verdicts (1976-1987)
-- | Racial bias analysis from Radelet and Pierce
deathPenalty :: Dataset
deathPenalty =
  { id: "death-penalty"
  , title: "Racial Bias in FL Death Penalty Verdicts 1976-1987"
  , description: "Death penalty verdicts for black and white defendants in Florida murder trials."
  , source: "Radelet and Pierce (1991). Florida Law Review."
  , row1Label: "Black victim"
  , row2Label: "White victim"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Murder Trials", outcome: "# Death Penalty", percent: "% Death Penalty" }
  , colALabel: "Black def."
  , colBLabel: "White def."
  , row1: { countA: 143.0, countB: 16.0, outcomeA: 4.0, outcomeB: 0.0 }
  , row2: { countA: 48.0, countB: 467.0, outcomeA: 11.0, outcomeB: 53.0 }
  , axisLabels: { x: "Percent white victim", y: "Percent receiving death penalty" }
  , initialLv: { a: 25.0, b: 97.0 }
  }

-- | Airline Flight Delays
-- | Alaska Airlines vs America West comparison
airlines :: Dataset
airlines =
  { id: "airlines"
  , title: "Flight Delays: Alaska Airlines vs America West"
  , description: "Comparison of flight delay rates between two airlines across different origin airports."
  , source: "Moore, McCabe, Craig."
  , row1Label: "Los Angeles"
  , row2Label: "Phoenix"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Flights", outcome: "# Delayed", percent: "% Delayed" }
  , colALabel: "Alaska"
  , colBLabel: "America West"
  , row1: { countA: 559.0, countB: 811.0, outcomeA: 62.0, outcomeB: 117.0 }
  , row2: { countA: 233.0, countB: 5255.0, outcomeA: 12.0, outcomeB: 415.0 }
  , axisLabels: { x: "Percent originating in Phoenix", y: "Percent delayed" }
  , initialLv: { a: 29.0, b: 87.0 }
  }

-- | Civil Rights Act of 1964 Voting
-- | Congressional voting patterns by party and region
civilRights :: Dataset
civilRights =
  { id: "civil-rights"
  , title: "House Voting on the Civil Rights Act of 1964"
  , description: "How Democrats and Republicans voted on the Civil Rights Act, split by Northern vs Southern representatives."
  , source: "Wikipedia: Simpson's Paradox."
  , row1Label: "Northern"
  , row2Label: "Southern"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Representatives", outcome: "# in Favor", percent: "% in Favor" }
  , colALabel: "Democrat"
  , colBLabel: "Republican"
  , row1: { countA: 154.0, countB: 162.0, outcomeA: 145.0, outcomeB: 138.0 }
  , row2: { countA: 94.0, countB: 10.0, outcomeA: 7.0, outcomeB: 0.0 }
  , axisLabels: { x: "Percent Southern", y: "Percent in favor" }
  , initialLv: { a: 37.9, b: 5.8 }
  }

-- | 20-Year Smoker Survival Study
-- | Survival rates stratified by age
smokers :: Dataset
smokers =
  { id: "smokers"
  , title: "20 Year Survival: Smokers vs. Non-smokers"
  , description: "Twenty-year survival outcomes for women, comparing smokers and non-smokers across age groups."
  , source: "Vanderpump et al. (1996). Thyroid 6(3):155-160."
  , row1Label: "Under 65"
  , row2Label: "65+"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Women", outcome: "# Alive", percent: "% Alive" }
  , colALabel: "Smoker"
  , colBLabel: "Non-smoker"
  , row1: { countA: 533.0, countB: 539.0, outcomeA: 436.0, outcomeB: 474.0 }
  , row2: { countA: 49.0, countB: 193.0, outcomeA: 7.0, outcomeB: 28.0 }
  , axisLabels: { x: "Percent 65 or older", y: "Percent alive" }
  , initialLv: { a: 8.4, b: 26.4 }
  }

-- | House Pets Data
-- | Dogs vs cats kept indoors by size
housePets :: Dataset
housePets =
  { id: "pets"
  , title: "House Pets: Dogs vs Cats Indoors"
  , description: "Whether dogs or cats are more likely to be kept indoors, stratified by pet size."
  , source: "Schneiter (2012). Hypothetical study data."
  , row1Label: "Small"
  , row2Label: "Large"
  , combinedLabel: "Combined"
  , colGroupLabels: { count: "# Pets", outcome: "# in house", percent: "% in house" }
  , colALabel: "Dogs"
  , colBLabel: "Cats"
  , row1: { countA: 12.0, countB: 42.0, outcomeA: 7.0, outcomeB: 17.0 }
  , row2: { countA: 83.0, countB: 8.0, outcomeA: 23.0, outcomeB: 2.0 }
  , axisLabels: { x: "Percent large", y: "Percent in house" }
  , initialLv: { a: 87.4, b: 16.0 }
  }
