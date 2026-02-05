-- | Core types for Type Explorer
-- |
-- | Defines the data model for visualizing type relationships.
module TypeExplorer.Types where

import Prelude
import Data.Maybe (Maybe(..))

-- =============================================================================
-- Type Information
-- =============================================================================

-- | Kind of type declaration
data TypeKind
  = DataType        -- data Foo = ...
  | NewtypeDecl     -- newtype Bar = ...
  | TypeAlias       -- type Baz = ...
  | TypeClassDecl   -- class Qux where ...

derive instance eqTypeKind :: Eq TypeKind

instance showTypeKind :: Show TypeKind where
  show = case _ of
    DataType -> "data"
    NewtypeDecl -> "newtype"
    TypeAlias -> "type"
    TypeClassDecl -> "class"

-- | A type declaration from the codebase
type TypeInfo =
  { id :: Int
  , name :: String
  , moduleName :: String
  , packageName :: String
  , kind :: TypeKind
  , typeParameters :: Array String
  , instanceCount :: Int      -- Number of class instances this type has
  , maturityLevel :: Int      -- 0-8 based on core class instances (Eq, Ord, Show, etc.)
  }

-- | An instance relationship
type InstanceInfo =
  { typeId :: Int
  , className :: String
  , classModule :: String
  , constraints :: Array String
  }

-- =============================================================================
-- Link Types
-- =============================================================================

-- | Types of relationships between types
data LinkType
  = InstanceOf      -- Type implements Class
  | UsedIn          -- Type appears in function signature
  | SameModule      -- Types are in the same module
  | Superclass      -- Class extends another Class
  | TypeReference   -- Type references another type in its definition

derive instance eqLinkType :: Eq LinkType

instance showLinkType :: Show LinkType where
  show = case _ of
    InstanceOf -> "instance"
    UsedIn -> "usage"
    SameModule -> "module"
    Superclass -> "superclass"
    TypeReference -> "reference"

-- | Link between types
type TypeLink =
  { source :: Int        -- TypeInfo id
  , target :: Int        -- TypeInfo id
  , linkType :: LinkType
  }

-- =============================================================================
-- Clustering
-- =============================================================================

-- | Strategies for clustering types in the visualization
data ClusterStrategy
  = ByPackage        -- One cluster per package
  | ByMaturity       -- Group by instance coverage level
  | ByTypeKind       -- Data vs Newtype vs Class vs Alias
  | ByModule         -- One cluster per module (may be many)

derive instance eqClusterStrategy :: Eq ClusterStrategy

-- =============================================================================
-- View Types
-- =============================================================================

-- | Available visualization views
data ViewMode
  = ForceGraphView   -- Force-directed graph of types
  | MatrixView       -- Interpreter x Expression matrix

derive instance eqViewMode :: Eq ViewMode

-- =============================================================================
-- Filter Types
-- =============================================================================

-- | Filter for type display
data TypeFilter
  = ShowAllTypes
  | ShowDataTypes
  | ShowNewtypes
  | ShowTypeClasses
  | ShowLowMaturity  -- Types missing common instances

derive instance eqTypeFilter :: Eq TypeFilter

-- =============================================================================
-- Application State
-- =============================================================================

-- | Application state
type State =
  { types :: Array TypeInfo
  , links :: Array TypeLink
  , instances :: Array InstanceInfo
  , selectedType :: Maybe Int        -- Selected type id
  , filter :: TypeFilter
  , clusterStrategy :: ClusterStrategy
  , viewMode :: ViewMode
  , loading :: Boolean
  , error :: Maybe String
  }

-- | Initial state
initialState :: State
initialState =
  { types: []
  , links: []
  , instances: []
  , selectedType: Nothing
  , filter: ShowAllTypes
  , clusterStrategy: ByPackage
  , viewMode: ForceGraphView
  , loading: true
  , error: Nothing
  }

-- =============================================================================
-- Matrix View Types (for Interpreter x Expression)
-- =============================================================================

-- | Information about an interpreter (for matrix view)
type InterpreterInfo =
  { name :: String
  , moduleName :: String
  , implementedClasses :: Array String
  }

-- | Information about an expression class (for matrix view)
type ExpressionClassInfo =
  { name :: String
  , moduleName :: String
  , methods :: Array String
  }

-- | Matrix data for interpreter x expression view
type InterpreterMatrix =
  { interpreters :: Array InterpreterInfo
  , expressionClasses :: Array ExpressionClassInfo
  , matrix :: Array (Array Boolean)  -- interpreters x classes
  }

-- =============================================================================
-- Colors
-- =============================================================================

-- | Color palette for type visualization
-- | Based on maturity level and type kind
colors ::
  { highMaturity :: String      -- Types with many instances
  , mediumMaturity :: String    -- Types with some instances
  , lowMaturity :: String       -- Types with few/no instances
  , typeClass :: String         -- Type class definitions
  , linkInstance :: String      -- Instance relationship
  , linkUsage :: String         -- Usage relationship
  , linkModule :: String        -- Same-module relationship
  , linkSuperclass :: String    -- Superclass relationship
  , text :: String
  , bg :: String
  }
colors =
  { highMaturity: "#c9a227"     -- Gold (well-specified)
  , mediumMaturity: "#4a90d9"   -- Blue (partial coverage)
  , lowMaturity: "#8a8a8a"      -- Gray (under-specified)
  , typeClass: "#7b4aa0"        -- Purple (class definitions)
  , linkInstance: "#4caf50"     -- Green
  , linkUsage: "#ff9800"        -- Orange
  , linkModule: "#cccccc"       -- Light gray
  , linkSuperclass: "#e91e63"   -- Pink
  , text: "#1a1a2e"             -- Navy
  , bg: "#faf6ed"               -- Cream
  }
