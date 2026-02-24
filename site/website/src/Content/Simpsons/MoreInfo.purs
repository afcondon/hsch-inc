-- | Auto-generated from Markdown. DO NOT EDIT.
-- | Source: See corresponding .md file in content/
module Content.Simpsons.MoreInfo where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Rendered markdown content
content :: forall w i. HH.HTML w i
content =
  HH.div_
    [ HH.h2_ [ HH.text "More Information (original credits from ", HH.a [ HP.href "http://setosa.io/simpsons", HP.target "_blank" ] [ HH.text "setosa.io/simpsons" ], HH.text " site)" ]
    , HH.ul_
      [
      HH.li_ [ HH.a [ HP.href "http://en.wikipedia.org/wiki/Simpson's_paradox", HP.target "_blank" ] [ HH.text "Wikipedia" ] ]
      , HH.li_ [ HH.text "This project drew on the Simpson’s Paradox Java Applet by Dr. Kady Schneiter at Utah State University, who has a ", HH.a [ HP.href "http://www.math.usu.edu/~schneit/CTIS/", HP.target "_blank" ] [ HH.text "bunch" ], HH.text " of neat illustrative Java applets." ]
      , HH.li_ [ HH.a [ HP.href "http://plato.stanford.edu/entries/paradox-simpson/", HP.target "_blank" ] [ HH.text "Stanford Encyclopedia of Philosophy" ] ]
      , HH.li_ [ HH.a [ HP.href "http://www.stat.osu.edu/~biostat/newsletters/volume2_2/article_vol2_2.html", HP.target "_blank" ] [ HH.text "Smoking Example" ] ]
      , HH.li_ [ HH.a [ HP.href "https://www.jstor.org/stable/1739581", HP.target "_blank" ] [ HH.text "Bickel et al. (1975) - “Sex Bias in Graduate Admissions: Data from Berkeley”" ], HH.text " (Science, Vol. 187) ", HH.em_ [ HH.text "(link updated)" ] ]
      , HH.li_ [ HH.a [ HP.href "http://www.bmj.com/content/309/6967/1480", HP.target "_blank" ] [ HH.text "Confounding and Simpson’s Paradox" ], HH.text " from the British Medical Journal" ]
      ]
    , HH.h2_ [ HH.text "Makers" ]
    , HH.p_ [ HH.text "A project of the ", HH.a [ HP.href "http://vudlab.com/#/", HP.target "_blank" ] [ HH.text "Visualizing Urban Data ideaLab" ], HH.text " at UC Berkeley. Created in ", HH.a [ HP.href "http://d3js.org/", HP.target "_blank" ] [ HH.text "d3.js" ], HH.text " and ", HH.a [ HP.href "http://angularjs.org/", HP.target "_blank" ] [ HH.text "AngularJS" ], HH.text " by ", HH.a [ HP.href "https://twitter.com/LewisLehe", HP.target "_blank" ] [ HH.text "Lewis Lehe" ], HH.text " and ", HH.a [ HP.href "http://vctr.me/", HP.target "_blank" ] [ HH.text "Victor Powell" ], HH.text "." ]
    , HH.p_ [ HH.text "Lewis Lehe is a PhD student in Transportation Engineering at UC Berkeley, and Victor Powell is a freelance developer, JavaScript instructor and yinzer." ]
    ]
