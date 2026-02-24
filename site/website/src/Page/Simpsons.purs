-- | Simpson's Paradox page with A-J grid layout
-- | Originally auto-generated, now manually maintained
module Page.Simpsons where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Type.Proxy (Proxy(..))

-- Import viz components from unified module
import D3.Viz.Simpsons.Components as Viz

-- =============================================================================
-- Types
-- =============================================================================

type State = {}

data Action = Initialize

data Query a = NoOp a

type Slots =
  ( donutcharts :: H.Slot Viz.SimpleQuery Void Unit
  , linechart :: H.Slot Viz.SimpleQuery Void Unit
  , forceviz :: H.Slot Viz.SimpleQuery Void Unit
  , scatterchart :: H.Slot Viz.SimpleQuery Void Unit
  , datatable :: H.Slot Viz.SimpleQuery Void Unit
  , postscriptcards :: H.Slot Viz.SimpleQuery Void Unit
  , illustration :: H.Slot Viz.SimpleQuery Void Unit
  )

-- =============================================================================
-- Slot Proxies
-- =============================================================================

_donutcharts :: Proxy "donutcharts"
_donutcharts = Proxy

_linechart :: Proxy "linechart"
_linechart = Proxy

_forceviz :: Proxy "forceviz"
_forceviz = Proxy

_scatterchart :: Proxy "scatterchart"
_scatterchart = Proxy

_datatable :: Proxy "datatable"
_datatable = Proxy

_postscriptcards :: Proxy "postscriptcards"
_postscriptcards = Proxy

_illustration :: Proxy "illustration"
_illustration = Proxy

-- =============================================================================
-- Component
-- =============================================================================

component :: forall i o m. MonadAff m => H.Component Query i o m
component = H.mkComponent
  { initialState: \_ -> {}
  , render
  , eval: H.mkEval H.defaultEval
      { initialize = Just Initialize
      }
  }

-- =============================================================================
-- Render
-- =============================================================================

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render _state =
  HH.div
    [ HP.classes [ HH.ClassName "simpsons-standalone" ] ]
    [ -- Acknowledgement banner
      HH.div
        [ HP.classes [ HH.ClassName "acknowledgement-banner" ] ]
        [ HH.text "Based on work by "
        , HH.a [ HP.href "https://twitter.com/LewisLehe", HP.target "_blank" ] [ HH.text "Lewis Lehe" ]
        , HH.text " & "
        , HH.a [ HP.href "http://vctr.me/", HP.target "_blank" ] [ HH.text "Victor Powell" ]
        , HH.text " at "
        , HH.a [ HP.href "http://vudlab.com/", HP.target "_blank" ] [ HH.text "VUDlab" ]
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "page-grid" ] ]
        [ renderSectionA
        , renderSectionB
        , renderSectionC
        , renderSectionD
        , renderSectionEFG  -- Combined illustration section with sliders
        , renderSectionH
        , renderSectionI
        , renderSectionJ
        ]
    ]

-- | Section A
renderSectionA :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionA =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-A" ] ]
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
      , HH.h3_ [ HH.text "What is Simpson’s paradox?" ]
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

-- | Section B: Donut charts and line chart
renderSectionB :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionB =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-B", HH.ClassName "simpsons-donuts" ] ]
    [ HH.slot _donutcharts unit Viz.donutChartsComponent unit absurd
    , HH.slot _linechart unit Viz.lineChartComponent unit absurd
    ]

-- | Section C: Proper Pooling
renderSectionC :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionC =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-C", HH.ClassName "simpsons-proper-pooling" ] ]
    [ HH.h2_ [ HH.text "Proper Pooling" ]
    , HH.p_ [ HH.text "By “properly pooled,” the investigators at Berkeley meant “broken down by department.” Men more often applied to science departments, while women inclined towards humanities. Science departments require special technical skills but accept a large percentage of qualified applicants. In contrast, humanities departments only require a standard undergrad curriculum but have fewer slots." ]
      , HH.p_ [ HH.text "The authors concluded that any sexism occurred before Berkeley ever saw the applications:" ]
      , HH.blockquote_
        [
        HH.p_ [ HH.text "Women are shunted by their socialization and education toward fields of graduate study that are generally more crowded, less > productive of completed degrees, and less well funded, and that frequently offer poorer professional employment prospects." ]
        , HH.ul_
          [
          HH.li_ [ HH.text "Bickel et al. (1975), p. 403" ]
          ]
        ]
      , HH.p_ [ HH.text "To the right are data on the six largest departments, but the names have been changed to protect the innocent." ]
    ]

-- | Section D: Departments
renderSectionD :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionD =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-D", HH.ClassName "simpsons-interactive" ] ]
    [ HH.h2_ [ HH.text "Departments" ]
    , HH.p_
        [
        HH.slot _forceviz unit Viz.forceVizComponent unit absurd
        ]
    ]

-- | Section E+F+G: Illustration with sliders, scatter chart, and data table
renderSectionEFG :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionEFG =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-E", HH.ClassName "section-illustration" ] ]
    [ HH.h2_ [ HH.text "Illustration" ]
    , HH.p_ [ HH.text "Suppose there are two departments: one easy, one hard ('hard' as in 'hard to get into'). The sliders below set what percentage each gender applies to the easy department. Both departments prefer women, but if too many women apply to the hard one, their acceptance rate drops below the men's." ]
    , HH.slot _illustration unit Viz.illustrationComponent unit absurd
    ]

-- | Section H: What Simpson's paradox is not
renderSectionH :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionH =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-H" ] ]
    [ HH.h2_ [ HH.text "What Simpson's paradox is not" ]
    , HH.p_ [ HH.em_ [ HH.text "Simpson’s:" ], HH.text " It was ", HH.a [ HP.href "http://www.jstor.org/discover/10.2307/2331677?uid=2&uid=4&sid=21102567680247", HP.target "_blank" ] [ HH.text "first mentioned" ], HH.text " by British statistician ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Udny_Yule", HP.target "_blank" ] [ HH.text "Udny Yule" ], HH.text " in 1903." ]
      , HH.p_ [ HH.em_ [ HH.text "A paradox:" ], HH.text " Simpson’s paradox is just a special case of ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Omitted-variable_bias", HP.target "_blank" ] [ HH.text "ommitted variable bias" ], HH.text ". W.V. Quine would call it a ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Paradox#Quine.27s_classification_of_paradoxes", HP.target "_blank" ] [ HH.text "veridical paradox" ], HH.text "." ]
      , HH.p_ [ HH.em_ [ HH.text "Every ommitted variable problem:" ], HH.text " Women earn only 77 percent of what men do, but according to Cornell economists ", HH.a [ HP.href "http://digitalcommons.ilr.cornell.edu/cgi/viewcontent.cgi?article=1248&context=ilrreview", HP.target "_blank" ] [ HH.text "Francine Blau and Lawrence Kahn" ], HH.text ", accounting for work experience, education, industry, and unionization shrinks the gap to 91 percent (p. 52). So, discrimination matters less than the ", HH.code_ [ HH.text "77 percent" ], HH.text " stat would lead you to believe. But is this Simpson’s paradox? No, because the correction isn’t large enough for the effect of gender to change sign." ]
      , HH.h3_ [ HH.text "Why it matters" ]
      , HH.p_ [ HH.text "Simpson’s paradox usually fools us on tests of performance. In a ", HH.a [ HP.href "http://en.wikipedia.org/wiki/Simpson's_paradox#Kidney_stone_treatment", HP.target "_blank" ] [ HH.text "famous example" ], HH.text ", researchers concluded that a newer treatment for kidney stones was more effective than traditional surgery, but it was ", HH.a [ HP.href "http://www.bmj.com/content/309/6967/1480", HP.target "_blank" ] [ HH.text "later revealed" ], HH.text " that the newer treatment was more often being used on small kidney stones. More recently, ", HH.a [ HP.href "http://educationnext.org/are-wisconsin-schools-better-than-those-in-texas/", HP.target "_blank" ] [ HH.text "on elementary school tests" ], HH.text ", minority students in Texas outperform their peers in Wisconsin, but Texas has so many minority students that Wisconsin beats it in state rankings. It would be a shame if Simpson’s paradox led doctors to prescribe ineffective treatments or Texas schools to waste money copying Wisconsin." ]
    ]

-- | Section I: More Information
renderSectionI :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionI =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-I", HH.ClassName "simpsons-more-info" ] ]
    [ HH.h2_ [ HH.text "More Information" ]
    , HH.ul_
        [
        HH.li_ [ HH.a [ HP.href "http://en.wikipedia.org/wiki/Simpson's_paradox", HP.target "_blank" ] [ HH.text "Wikipedia" ] ]
        , HH.li_ [ HH.text "This project drew on the Simpson’s Paradox Java Applet by Dr. Kady Schneiter at Utah State University, who has a ", HH.a [ HP.href "http://www.math.usu.edu/~schneit/CTIS/", HP.target "_blank" ] [ HH.text "bunch" ], HH.text " of neat illustrative Java applets." ]
        , HH.li_ [ HH.a [ HP.href "http://plato.stanford.edu/entries/paradox-simpson/", HP.target "_blank" ] [ HH.text "Stanford Encyclopedia of Philosophy" ] ]
        , HH.li_ [ HH.a [ HP.href "http://www.stat.osu.edu/~biostat/newsletters/volume2_2/article_vol2_2.html", HP.target "_blank" ] [ HH.text "Smoking Example" ] ]
        , HH.li_ [ HH.a [ HP.href "https://www.jstor.org/stable/1739581", HP.target "_blank" ] [ HH.text "Bickel et al. (1975) - “Sex Bias in Graduate Admissions: Data from Berkeley”" ], HH.text " (Science, Vol. 187) ", HH.em_ [ HH.text "(link updated)" ] ]
        , HH.li_ [ HH.a [ HP.href "http://www.bmj.com/content/309/6967/1480", HP.target "_blank" ] [ HH.text "Confounding and Simpson’s Paradox" ], HH.text " from the British Medical Journal" ]
        ]
      , HH.h3_ [ HH.text "Makers" ]
      , HH.p_ [ HH.text "A project of the ", HH.a [ HP.href "http://vudlab.com/#/", HP.target "_blank" ] [ HH.text "Visualizing Urban Data ideaLab" ], HH.text " at UC Berkeley. Created in ", HH.a [ HP.href "http://d3js.org/", HP.target "_blank" ] [ HH.text "d3.js" ], HH.text " and ", HH.a [ HP.href "http://angularjs.org/", HP.target "_blank" ] [ HH.text "AngularJS" ], HH.text " by ", HH.a [ HP.href "https://twitter.com/LewisLehe", HP.target "_blank" ] [ HH.text "Lewis Lehe" ], HH.text " and ", HH.a [ HP.href "http://vctr.me/", HP.target "_blank" ] [ HH.text "Victor Powell" ], HH.text "." ]
      , HH.p_ [ HH.text "Lewis Lehe is a PhD student in Transportation Engineering at UC Berkeley, and Victor Powell is a freelance developer, JavaScript instructor and yinzer." ]
    ]

-- | Section J: More Examples
renderSectionJ :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderSectionJ =
  HH.div
    [ HP.classes [ HH.ClassName "page-section", HH.ClassName "section-J", HH.ClassName "simpsons-postscript" ] ]
    [ HH.h2_ [ HH.text "More Examples" ]
    , HH.p_ [ HH.text "Use the sliders below to explore seven classic Simpson’s Paradox examples from real-world data." ]
      , HH.p_
        [
        HH.slot _postscriptcards unit Viz.postscriptCardsComponent unit absurd
        ]
    ]

-- =============================================================================
-- Styles (copy to CSS file)
-- =============================================================================
{-

.page-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-areas:
    "A B"
    "C D"
    "E E"
    "F G"
    "H I"
    "J J";
  gap: 2rem;
  padding: 2rem;
}

.section-A { grid-area: A; }
.section-B { grid-area: B; }
.section-C { grid-area: C; }
.section-D { grid-area: D; }
.section-E { grid-area: E; }
.section-F { grid-area: F; }
.section-G { grid-area: G; }
.section-H { grid-area: H; }
.section-I { grid-area: I; }
.section-J { grid-area: J; }

@media (max-width: 768px) {
  .page-grid {
    grid-template-columns: 1fr;
    grid-template-areas: "A" "B" "C" "D" "E" "F" "G" "H" "I" "J";
  }
}

-}
