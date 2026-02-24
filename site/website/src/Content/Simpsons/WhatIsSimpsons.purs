-- | Auto-generated from Markdown. DO NOT EDIT.
-- | Source: See corresponding .md file in content/
module Content.Simpsons.WhatIsSimpsons where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Rendered markdown content
content :: forall w i. HH.HTML w i
content =
  HH.div_
    [ HH.h2_ [ HH.text "What Simpson’s paradox is not" ]
    , HH.p_ [ HH.em_ [ HH.text "Simpson’s:" ], HH.text " It was ", HH.a [ HP.href "http://www.jstor.org/discover/10.2307/2331677?uid=2&uid=4&sid=21102567680247", HP.target "_blank" ] [ HH.text "first mentioned" ], HH.text " by British statistician ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Udny_Yule", HP.target "_blank" ] [ HH.text "Udny Yule" ], HH.text " in 1903." ]
    , HH.p_ [ HH.em_ [ HH.text "A paradox:" ], HH.text " Simpson’s paradox is just a special case of ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Omitted-variable_bias", HP.target "_blank" ] [ HH.text "ommitted variable bias" ], HH.text ". W.V. Quine would call it a ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Paradox#Quine.27s_classification_of_paradoxes", HP.target "_blank" ] [ HH.text "veridical paradox" ], HH.text "." ]
    , HH.p_ [ HH.em_ [ HH.text "Every ommitted variable problem:" ], HH.text " Women earn only 77 percent of what men do, but according to Cornell economists ", HH.a [ HP.href "http://digitalcommons.ilr.cornell.edu/cgi/viewcontent.cgi?article=1248&context=ilrreview", HP.target "_blank" ] [ HH.text "Francine Blau and Lawrence Kahn" ], HH.text ", accounting for work experience, education, industry, and unionization shrinks the gap to 91 percent (p. 52). So, discrimination matters less than the ", HH.code_ [ HH.text "77 percent" ], HH.text " stat would lead you to believe. But is this Simpson’s paradox? No, because the correction isn’t large enough for the effect of gender to change sign." ]
    , HH.h2_ [ HH.text "Why it matters" ]
    , HH.p_ [ HH.text "Simpson’s paradox usually fools us on tests of performance. In a ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Simpson's_paradox#Kidney_stone_treatment", HP.target "_blank" ] [ HH.text "famous example" ], HH.text ", researchers concluded that a newer treatment for kidney stones was more effective than traditional surgery, but it was ", HH.a [ HP.href "http://www.bmj.com/content/309/6967/1480", HP.target "_blank" ] [ HH.text "later revealed" ], HH.text " that the newer treatment was more often being used on small kidney stones. More recently, ", HH.a [ HP.href "http://educationnext.org/are-wisconsin-schools-better-than-those-in-texas/", HP.target "_blank" ] [ HH.text "on elementary school tests" ], HH.text ", minority students in Texas outperform their peers in Wisconsin, but Texas has so many minority students that Wisconsin beats it in state rankings. It would be a shame if Simpson’s paradox led doctors to prescribe ineffective treatments or Texas schools to waste money copying Wisconsin." ]
    ]
