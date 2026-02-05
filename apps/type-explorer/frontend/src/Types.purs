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
  = ForceGraphView      -- Force-directed graph of types
  | TypeClassesView     -- Combined: Matrix + TypeClass grid (splitscreen)

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
  , matrixData :: Maybe InterpreterMatrix
  , typeClassData :: Maybe TypeClassGridData
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
  , matrixData: Nothing
  , typeClassData: Nothing
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
-- Type Class Grid Types
-- =============================================================================

-- | Information about a single type class for grid display
type TypeClassGridInfo =
  { id :: Int
  , name :: String
  , moduleName :: String
  , packageName :: String
  , methodCount :: Int
  , instanceCount :: Int
  }

-- | Summary statistics for type classes
type TypeClassSummary =
  { totalMethods :: Int
  , totalInstances :: Int
  }

-- | Full type class grid data
type TypeClassGridData =
  { typeClasses :: Array TypeClassGridInfo
  , count :: Int
  , summary :: TypeClassSummary
  }

-- =============================================================================
-- Node Roles (for coloring)
-- =============================================================================

-- | Role of a type in the type graph (used for primary node coloring)
data NodeRole
  = RoleTypeClass         -- A typeclass definition
  | RoleInstanceProvider  -- A type that implements typeclasses
  | RoleSuperclass        -- A typeclass that extends another
  | RoleReferenced        -- A type that is used/referenced by others
  | RoleIsolated          -- No significant relationships

derive instance eqNodeRole :: Eq NodeRole

-- =============================================================================
-- Colors
-- =============================================================================

-- | Color palette for type visualization
-- | Primary distinction: Node role (typeclass/instance/reference)
-- | Secondary distinction: Link type
colors ::
  { -- Node colors by role (primary distinction)
    typeClass :: String         -- Purple: Type class definitions
  , instanceProvider :: String  -- Green: Types implementing typeclasses
  , superclass :: String        -- Pink: Typeclasses that are superclasses
  , referenced :: String        -- Blue: Types that are referenced
  , isolated :: String          -- Gray: Types with no relationships
  -- Link colors
  , linkInstance :: String      -- Instance relationship
  , linkUsage :: String         -- Usage relationship
  , linkModule :: String        -- Same-module relationship
  , linkSuperclass :: String    -- Superclass relationship
  -- Legacy (kept for compatibility)
  , highMaturity :: String
  , mediumMaturity :: String
  , lowMaturity :: String
  , text :: String
  , bg :: String
  }
colors =
  { -- Node colors by role
    typeClass: "#7b4aa0"        -- Purple (class definitions)
  , instanceProvider: "#4caf50" -- Green (types with instances)
  , superclass: "#e91e63"       -- Pink (superclass typeclasses)
  , referenced: "#4a90d9"       -- Blue (referenced types)
  , isolated: "#8a8a8a"         -- Gray (no relationships)
  -- Link colors
  , linkInstance: "#4caf50"     -- Green
  , linkUsage: "#ff9800"        -- Orange
  , linkModule: "#cccccc"       -- Light gray
  , linkSuperclass: "#e91e63"   -- Pink
  -- Legacy
  , highMaturity: "#c9a227"
  , mediumMaturity: "#4a90d9"
  , lowMaturity: "#8a8a8a"
  , text: "#1a1a2e"             -- Navy
  , bg: "#faf6ed"               -- Cream
  }
