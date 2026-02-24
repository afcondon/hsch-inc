-- | Auto-generated from Markdown. DO NOT EDIT.
-- | Source: See corresponding .md file in content/
module Content.Simpsons.WhyMatters where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Rendered markdown content
content :: forall w i. HH.HTML w i
content =
  HH.div_
    [ HH.h2_ [ HH.text "Why It Matters" ]
    , HH.p_ [ HH.text "Simpson’s Paradox isn’t just a statistical curiosity—it has real-world implications for how we interpret data:" ]
    , HH.ul_
      [
      HH.li_ [ HH.text "", HH.strong_ [ HH.text "Medical trials:" ], HH.text " A treatment might appear harmful overall but beneficial for every subgroup (or vice versa)." ]
      , HH.li_ [ HH.text "", HH.strong_ [ HH.text "Policy decisions:" ], HH.text " Aggregate statistics can be misleading when the groups being combined have different characteristics." ]
      , HH.li_ [ HH.text "", HH.strong_ [ HH.text "Discrimination cases:" ], HH.text " As the Berkeley case shows, what looks like bias in aggregate might disappear or reverse when properly analyzed." ]
      ]
    , HH.p_ [ HH.text "The lesson: ", HH.strong_ [ HH.text "always ask what lurking variables might be influencing your data" ], HH.text ". Aggregate statistics can tell a very different story than disaggregated ones." ]
    ]
