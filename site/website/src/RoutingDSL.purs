module Hylograph.RoutingDSL where

import Prelude hiding ((/))

import Hylograph.Website.Types (Route(..))
import Routing.Match (Match, lit, str, end)
import Routing.Match (root) as Match
import Control.Alt ((<|>))

-- | Routing DSL for matching URL paths to Routes
-- |
-- | This uses purescript-routing to provide cleaner URLs without hash fragments.
-- | Routes are matched top-to-bottom, first match wins.
routing :: Match Route
routing =
  Match.root *> routes

routes :: Match Route
routes =
  home
  <|> gettingStarted
  <|> howtoIndex
  <|> howtoTransitions
  <|> howtoForceGraphs
  <|> howtoHierarchical
  <|> howtoEvents
  <|> howtoLoadingData
  <|> howtoTooltips
  <|> howtoDebugging
  <|> howtoPerformance
  <|> understandingGrammar
  <|> understandingAttributes
  <|> understandingSelections
  <|> understandingScenes
  <|> understanding
  <|> referenceModule
  <|> reference
  <|> tourScrolly
  <|> tourMotionScrollyHATS
  <|> tourSimpsons
  <|> tourIndex
  <|> showcaseLuaEdge
  <|> simpsonsV2Route
  <|> showcase
  <|> moduleGraph
  <|> forcePlayground
  <|> treeBuilder
  <|> acknowledgements
  <|> rootRedirect
  <|> notFound

-- | Match: /home (landing page)
home :: Match Route
home = Home <$ lit "home" <* end

-- | Match: / (redirect to home)
rootRedirect :: Match Route
rootRedirect = Home <$ end

-- | Match: /getting-started
gettingStarted :: Match Route
gettingStarted = GettingStarted <$ lit "getting-started" <* end

-- | Match: /howto
howtoIndex :: Match Route
howtoIndex = HowtoIndex <$ lit "howto" <* end

-- | Match: /howto/transitions
howtoTransitions :: Match Route
howtoTransitions = HowtoTransitions <$ lit "howto" <* lit "transitions" <* end

-- | Match: /howto/force-graphs
howtoForceGraphs :: Match Route
howtoForceGraphs = HowtoForceGraphs <$ lit "howto" <* lit "force-graphs" <* end

-- | Match: /howto/hierarchical
howtoHierarchical :: Match Route
howtoHierarchical = HowtoHierarchical <$ lit "howto" <* lit "hierarchical" <* end

-- | Match: /howto/events
howtoEvents :: Match Route
howtoEvents = HowtoEvents <$ lit "howto" <* lit "events" <* end

-- | Match: /howto/loading-data
howtoLoadingData :: Match Route
howtoLoadingData = HowtoLoadingData <$ lit "howto" <* lit "loading-data" <* end

-- | Match: /howto/tooltips
howtoTooltips :: Match Route
howtoTooltips = HowtoTooltips <$ lit "howto" <* lit "tooltips" <* end

-- | Match: /howto/debugging
howtoDebugging :: Match Route
howtoDebugging = HowtoDebugging <$ lit "howto" <* lit "debugging" <* end

-- | Match: /howto/performance
howtoPerformance :: Match Route
howtoPerformance = HowtoPerformance <$ lit "howto" <* lit "performance" <* end

-- | Match: /understanding
understanding :: Match Route
understanding = Understanding <$ lit "understanding" <* end

-- | Match: /understanding/grammar
understandingGrammar :: Match Route
understandingGrammar = UnderstandingGrammar <$ lit "understanding" <* lit "grammar" <* end

-- | Match: /understanding/attributes
understandingAttributes :: Match Route
understandingAttributes = UnderstandingAttributes <$ lit "understanding" <* lit "attributes" <* end

-- | Match: /understanding/selections
understandingSelections :: Match Route
understandingSelections = UnderstandingSelections <$ lit "understanding" <* lit "selections" <* end

-- | Match: /understanding/scenes
understandingScenes :: Match Route
understandingScenes = UnderstandingScenes <$ lit "understanding" <* lit "scenes" <* end

-- | Match: /reference/:moduleName
referenceModule :: Match Route
referenceModule = ReferenceModule <$> (lit "reference" *> str) <* end

-- | Match: /reference
reference :: Match Route
reference = Reference <$ lit "reference" <* end

-- | Match: /tour/scrolly (from the basics - three circles)
tourScrolly :: Match Route
tourScrolly = TourScrolly <$ lit "tour" <* lit "scrolly" <* end

-- | Match: /tour/scrolly2 (HATS tick-driven version - working)
tourMotionScrollyHATS :: Match Route
tourMotionScrollyHATS = TourMotionScrollyHATS <$ lit "tour" <* lit "scrolly2" <* end

-- | Match: /tour/simpsons
tourSimpsons :: Match Route
tourSimpsons = TourSimpsons <$ lit "tour" <* lit "simpsons" <* end

-- | Match: /tour (index page)
tourIndex :: Match Route
tourIndex = TourIndex <$ lit "tour" <* end

-- | Match: /showcase/lua-edge
showcaseLuaEdge :: Match Route
showcaseLuaEdge = ShowcaseLuaEdge <$ lit "showcase" <* lit "lua-edge" <* end

-- | Match: /simpsons-v2
simpsonsV2Route :: Match Route
simpsonsV2Route = SimpsonsV2 <$ lit "simpsons-v2" <* end

-- | Match: /showcase
showcase :: Match Route
showcase = Showcase <$ lit "showcase" <* end

-- | Match: /module-graph
moduleGraph :: Match Route
moduleGraph = ModuleGraph <$ lit "module-graph" <* end

-- | Match: /force-playground
forcePlayground :: Match Route
forcePlayground = ForcePlayground <$ lit "force-playground" <* end

-- | Match: /tree-builder
treeBuilder :: Match Route
treeBuilder = TreeBuilder <$ lit "tree-builder" <* end

-- | Match: /acknowledgements
acknowledgements :: Match Route
acknowledgements = Acknowledgements <$ lit "acknowledgements" <* end

-- | Fallback: everything else is NotFound
notFound :: Match Route
notFound = pure NotFound

-- | Convert a Route back to a URL path (for links and navigation)
routeToPath :: Route -> String
routeToPath Home = "/home"
routeToPath GettingStarted = "/getting-started"
routeToPath HowtoIndex = "/howto"
routeToPath HowtoTransitions = "/howto/transitions"
routeToPath HowtoForceGraphs = "/howto/force-graphs"
routeToPath HowtoHierarchical = "/howto/hierarchical"
routeToPath HowtoEvents = "/howto/events"
routeToPath HowtoLoadingData = "/howto/loading-data"
routeToPath HowtoTooltips = "/howto/tooltips"
routeToPath HowtoDebugging = "/howto/debugging"
routeToPath HowtoPerformance = "/howto/performance"
routeToPath Understanding = "/understanding"
routeToPath UnderstandingGrammar = "/understanding/grammar"
routeToPath UnderstandingAttributes = "/understanding/attributes"
routeToPath UnderstandingSelections = "/understanding/selections"
routeToPath UnderstandingScenes = "/understanding/scenes"
routeToPath Reference = "/reference"
routeToPath (ReferenceModule moduleName) = "/reference/" <> moduleName
routeToPath TourIndex = "/tour"
routeToPath TourScrolly = "/tour/scrolly"
routeToPath TourMotionScrollyHATS = "/tour/scrolly2"
routeToPath TourSimpsons = "/tour/simpsons"
routeToPath Showcase = "/showcase"
routeToPath ShowcaseLuaEdge = "/showcase/lua-edge"
routeToPath SimpsonsV2 = "/simpsons-v2"
routeToPath ModuleGraph = "/module-graph"
routeToPath ForcePlayground = "/force-playground"
routeToPath TreeBuilder = "/tree-builder"
routeToPath Acknowledgements = "/acknowledgements"
routeToPath NotFound = "/not-found"
