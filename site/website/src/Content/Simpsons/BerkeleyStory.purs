-- | Auto-generated from Markdown. DO NOT EDIT.
-- | Source: See corresponding .md file in content/
module Content.Simpsons.BerkeleyStory where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Rendered markdown content
content :: forall w i. HH.HTML w i
content =
  HH.div_
    [ HH.p_ [ HH.text "In 1973, the University of California-Berkeley was sued for sex discrimination. The numbers looked pretty incriminating: the graduate schools had just accepted ", HH.em_ [ HH.text "44%" ], HH.text " of male applicants but only ", HH.em_ [ HH.text "35%" ], HH.text " of female applicants. When researchers looked at the evidence, though, they uncovered something surprising:" ]
    , HH.blockquote_
      [
      HH.p_ [ HH.text "If the data are properly pooled…there is a small but statistically significant bias in favor of women." ]
      , HH.ul_
        [
        HH.li_ [ HH.text "Bickel et al (1975), p. 403" ]
        ]
      ]
    , HH.p_ [ HH.text "It was a textbook case of Simpson’s paradox." ]
    , HH.h2_ [ HH.text "What is Simpson’s paradox?" ]
    , HH.p_ [ HH.text "Every Simpson’s paradox involves at least three variables:" ]
    , HH.ol_
      [
      HH.li_ [ HH.text "the explained" ]
      , HH.li_ [ HH.text "the observed explanatory" ]
      , HH.li_ [ HH.text "the lurking explanatory" ]
      ]
    , HH.p_ [ HH.text "If the effect of the observed explanatory variable on the explained variable changes directions when you account for the lurking explanatory variable, you’ve got a Simpson’s Paradox." ]
    , HH.p_ [ HH.text "For example, to the right, x appears to have a negative effect on y, but the opposite is true when you account for color. y is the explained variable, x the observed explanatory variable, and color the lurking explanatory variable." ]
    ]
