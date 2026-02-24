module Hylograph.Website.Types where

import Prelude

-- | Unique identifier for an example
type ExampleId = String

-- | Difficulty level of an example
data Difficulty
  = Beginner
  | Intermediate
  | Advanced

derive instance eqDifficulty :: Eq Difficulty
derive instance ordDifficulty :: Ord Difficulty

instance showDifficulty :: Show Difficulty where
  show Beginner = "Beginner"
  show Intermediate = "Intermediate"
  show Advanced = "Advanced"

difficultyToString :: Difficulty -> String
difficultyToString = show

difficultyEmoji :: Difficulty -> String
difficultyEmoji Beginner = "🟢"
difficultyEmoji Intermediate = "🟡"
difficultyEmoji Advanced = "🔴"

-- | Category of visualization
data Category
  = BasicChart
  | AdvancedLayout
  | Interactive
  | Interpreter
  | Application

derive instance eqCategory :: Eq Category
derive instance ordCategory :: Ord Category

instance showCategory :: Show Category where
  show BasicChart = "Basic Charts"
  show AdvancedLayout = "Advanced Layouts"
  show Interactive = "Interactive"
  show Interpreter = "Alternative Interpreters"
  show Application = "Applications"

categoryToString :: Category -> String
categoryToString = show

-- | Main documentation sections
data Section
  = UnderstandingSection  -- Explanation/concept pages
  | TutorialSection       -- Getting started tutorial
  | HowToSection          -- Step-by-step guides
  | APISection            -- API documentation

derive instance eqSection :: Eq Section
derive instance ordSection :: Ord Section

instance showSection :: Show Section where
  show UnderstandingSection = "Understanding"
  show TutorialSection = "Tutorial"
  show HowToSection = "How-To"
  show APISection = "API"

-- | Metadata for a single example
type ExampleMetadata = {
  id :: ExampleId
, title :: String
, description :: String
, about :: String  -- Detailed explanation of the example
, difficulty :: Difficulty
, category :: Category
, tags :: Array String
, thumbnail :: String
, hasInteractivity :: Boolean
, hasComparison :: Boolean
}

-- | Route in the application
data Route
  = Home            -- Landing page
  | GettingStarted  -- Tutorial: installation, setup, first project
  | HowtoIndex      -- How-to: index of all step-by-step guides
  -- How-to sub-pages
  | HowtoTransitions      -- Creating animated transitions
  | HowtoForceGraphs      -- Building force-directed graphs
  | HowtoHierarchical     -- Working with hierarchical data
  | HowtoEvents           -- Responding to user events
  | HowtoLoadingData      -- Loading external data
  | HowtoTooltips         -- Adding tooltips
  | HowtoDebugging        -- Debugging visualizations
  | HowtoPerformance      -- Performance optimization
  | Understanding   -- Conceptual overview: index page
  -- Understanding sub-pages
  | UnderstandingGrammar       -- Grammar of D3 in PSD3
  | UnderstandingAttributes    -- Type-safe attribute system with phantom types
  | UnderstandingSelections    -- Selection phantom types (Indexed Monad pattern)
  | UnderstandingScenes        -- Scene structures for interactive visualizations
  | Reference       -- Reference: API documentation index
  | ReferenceModule String  -- Reference: individual module page
  -- Tour Pages
  | TourIndex            -- Tour: index page
  | TourScrolly          -- Tour: From the Basics (three circles)
  | TourMotionScrollyHATS -- Tour: Motion & Animation (HATS version)
  | TourSimpsons         -- Tour: Simpson's Paradox (links to showcase)
  -- Showcase (complex app-like visualizations)
  | Showcase             -- Showcase: index page with hero and cards
  | ShowcaseLuaEdge      -- Showcase: Lua Edge Router architecture explanation
  | SimpsonsV2           -- Showcase: Simpson's Paradox micro-CMS version (page-compiler generated)
  -- Other
  | ModuleGraph     -- Module dependency graph (dogfooding!)
  | ForcePlayground -- Force simulation playground (using high-level runSimulation API)
  | TreeBuilder    -- Interactive tree builder for Tree API visualization
  -- Meta
  | Acknowledgements -- Credits and acknowledgements
  | NotFound

derive instance eqRoute :: Eq Route

instance showRoute :: Show Route where
  show Home = "Home"
  show GettingStarted = "Getting Started"
  show HowtoIndex = "How-to Guides"
  show HowtoTransitions = "How-to: Transitions"
  show HowtoForceGraphs = "How-to: Force Graphs"
  show HowtoHierarchical = "How-to: Hierarchical Data"
  show HowtoEvents = "How-to: Events"
  show HowtoLoadingData = "How-to: Loading Data"
  show HowtoTooltips = "How-to: Tooltips"
  show HowtoDebugging = "How-to: Debugging"
  show HowtoPerformance = "How-to: Performance"
  show Understanding = "Understanding"
  show UnderstandingGrammar = "Understanding: Grammar"
  show UnderstandingAttributes = "Understanding: Attributes"
  show UnderstandingSelections = "Understanding: Selections"
  show UnderstandingScenes = "Understanding: Scenes"
  show Reference = "API Reference"
  show (ReferenceModule moduleName) = "Module: " <> moduleName
  show TourIndex = "Tour"
  show TourScrolly = "Tour: From the Basics"
  show TourMotionScrollyHATS = "Tour: Motion & Animation"
  show TourSimpsons = "Tour: Simpson's Paradox"
  show Showcase = "Showcase"
  show ShowcaseLuaEdge = "Lua Edge Router"
  show SimpsonsV2 = "Simpson's Paradox"
  show ModuleGraph = "Module Graph"
  show ForcePlayground = "Force Playground"
  show TreeBuilder = "Tree Builder"
  show Acknowledgements = "Acknowledgements"
  show NotFound = "Not Found"
