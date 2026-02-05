-- | Data loader for Type Explorer
-- |
-- | Fetches type information from Minard API endpoints.
-- | Currently uses sample data; will connect to real API in Phase 3.
module TypeExplorer.Data.Loader
  ( loadTypeData
  , TypeData
  ) where

import Prelude

import Data.Either (Either(..))
import Effect.Aff (Aff)
import TypeExplorer.Types (TypeInfo, TypeLink, InstanceInfo, TypeKind(..), LinkType(..))

-- | Complete type data from API
type TypeData =
  { types :: Array TypeInfo
  , links :: Array TypeLink
  , instances :: Array InstanceInfo
  }

-- | Load type data from API
-- | TODO: Replace with actual API calls in Phase 3
loadTypeData :: Aff (Either String TypeData)
loadTypeData = pure $ Right sampleData

-- =============================================================================
-- Sample Data (Hylograph-inspired)
-- =============================================================================

sampleData :: TypeData
sampleData =
  { types: sampleTypes
  , links: sampleLinks
  , instances: sampleInstances
  }

sampleTypes :: Array TypeInfo
sampleTypes =
  -- Expression classes (TypeClass)
  [ { id: 1, name: "NumExpr", moduleName: "Hylograph.Expr.Expr", packageName: "hylograph-selection"
    , kind: TypeClassDecl, typeParameters: ["repr"], instanceCount: 12, maturityLevel: 8 }
  , { id: 2, name: "StringExpr", moduleName: "Hylograph.Expr.Expr", packageName: "hylograph-selection"
    , kind: TypeClassDecl, typeParameters: ["repr"], instanceCount: 10, maturityLevel: 7 }
  , { id: 3, name: "BoolExpr", moduleName: "Hylograph.Expr.Expr", packageName: "hylograph-selection"
    , kind: TypeClassDecl, typeParameters: ["repr"], instanceCount: 8, maturityLevel: 6 }
  , { id: 4, name: "TrigExpr", moduleName: "Hylograph.Expr.Expr", packageName: "hylograph-selection"
    , kind: TypeClassDecl, typeParameters: ["repr"], instanceCount: 6, maturityLevel: 5 }
  , { id: 5, name: "DatumExpr", moduleName: "Hylograph.Expr.Datum", packageName: "hylograph-selection"
    , kind: TypeClassDecl, typeParameters: ["repr", "datum"], instanceCount: 5, maturityLevel: 4 }

  -- Interpreter types (Newtype/Data)
  , { id: 10, name: "Eval", moduleName: "Hylograph.Expr.Interpreter.Eval", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: ["a"], instanceCount: 15, maturityLevel: 8 }
  , { id: 11, name: "EvalD", moduleName: "Hylograph.Expr.Interpreter.Eval", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: ["datum", "a"], instanceCount: 15, maturityLevel: 8 }
  , { id: 12, name: "SVG", moduleName: "Hylograph.Expr.Interpreter.SVG", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: ["a"], instanceCount: 12, maturityLevel: 7 }
  , { id: 13, name: "CodeGen", moduleName: "Hylograph.Expr.Interpreter.CodeGen", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: ["a"], instanceCount: 8, maturityLevel: 5 }
  , { id: 14, name: "English", moduleName: "Hylograph.Interpreter.English", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: ["a"], instanceCount: 6, maturityLevel: 4 }

  -- Core types
  , { id: 20, name: "Tree", moduleName: "Hylograph.HATS", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 3, maturityLevel: 6 }
  , { id: 21, name: "Attr", moduleName: "Hylograph.HATS", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 2, maturityLevel: 4 }
  , { id: 22, name: "SomeFold", moduleName: "Hylograph.HATS", packageName: "hylograph-selection"
    , kind: NewtypeDecl, typeParameters: [], instanceCount: 1, maturityLevel: 2 }

  -- Selection types
  , { id: 30, name: "Selection", moduleName: "Hylograph.Internal.Selection.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: ["state", "parent", "datum"], instanceCount: 4, maturityLevel: 5 }
  , { id: 31, name: "SEmpty", moduleName: "Hylograph.Internal.Selection.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 0, maturityLevel: 0 }
  , { id: 32, name: "SBoundOwns", moduleName: "Hylograph.Internal.Selection.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 0, maturityLevel: 0 }

  -- Layout types
  , { id: 40, name: "HierarchyNode", moduleName: "DataViz.Layout.Hierarchy.Types", packageName: "hylograph-layout"
    , kind: DataType, typeParameters: ["a"], instanceCount: 3, maturityLevel: 5 }
  , { id: 41, name: "SankeyNode", moduleName: "DataViz.Layout.Sankey.Types", packageName: "hylograph-layout"
    , kind: DataType, typeParameters: [], instanceCount: 2, maturityLevel: 3 }
  , { id: 42, name: "SankeyLink", moduleName: "DataViz.Layout.Sankey.Types", packageName: "hylograph-layout"
    , kind: DataType, typeParameters: [], instanceCount: 2, maturityLevel: 3 }

  -- Graph types
  , { id: 50, name: "Graph", moduleName: "Data.Graph.Types", packageName: "hylograph-graph"
    , kind: DataType, typeParameters: ["id", "node", "edge"], instanceCount: 5, maturityLevel: 6 }

  -- Simulation types
  , { id: 60, name: "SimulationNode", moduleName: "Hylograph.ForceEngine.Simulation", packageName: "hylograph-simulation"
    , kind: TypeAlias, typeParameters: ["r"], instanceCount: 0, maturityLevel: 1 }

  -- Under-specified types (low maturity)
  , { id: 70, name: "BrushConfig", moduleName: "Hylograph.Brush.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 0, maturityLevel: 0 }
  , { id: 71, name: "DragConfig", moduleName: "Hylograph.Internal.Behavior.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 0, maturityLevel: 0 }
  , { id: 72, name: "ZoomConfig", moduleName: "Hylograph.Internal.Behavior.Types", packageName: "hylograph-selection"
    , kind: DataType, typeParameters: [], instanceCount: 0, maturityLevel: 0 }
  ]

sampleLinks :: Array TypeLink
sampleLinks =
  -- Interpreter instances of expression classes
  [ { source: 10, target: 1, linkType: InstanceOf }  -- Eval implements NumExpr
  , { source: 10, target: 2, linkType: InstanceOf }  -- Eval implements StringExpr
  , { source: 10, target: 3, linkType: InstanceOf }  -- Eval implements BoolExpr
  , { source: 10, target: 4, linkType: InstanceOf }  -- Eval implements TrigExpr
  , { source: 11, target: 1, linkType: InstanceOf }  -- EvalD implements NumExpr
  , { source: 11, target: 5, linkType: InstanceOf }  -- EvalD implements DatumExpr
  , { source: 12, target: 1, linkType: InstanceOf }  -- SVG implements NumExpr
  , { source: 12, target: 2, linkType: InstanceOf }  -- SVG implements StringExpr
  , { source: 13, target: 1, linkType: InstanceOf }  -- CodeGen implements NumExpr
  , { source: 14, target: 1, linkType: InstanceOf }  -- English implements NumExpr

  -- Same module relationships
  , { source: 10, target: 11, linkType: SameModule }  -- Eval and EvalD
  , { source: 31, target: 32, linkType: SameModule }  -- SEmpty and SBoundOwns
  , { source: 41, target: 42, linkType: SameModule }  -- SankeyNode and SankeyLink
  , { source: 70, target: 71, linkType: SameModule }  -- Config types
  , { source: 71, target: 72, linkType: SameModule }

  -- Type references
  , { source: 20, target: 21, linkType: TypeReference }  -- Tree uses Attr
  , { source: 20, target: 22, linkType: TypeReference }  -- Tree uses SomeFold
  , { source: 30, target: 31, linkType: TypeReference }  -- Selection uses SEmpty
  , { source: 30, target: 32, linkType: TypeReference }  -- Selection uses SBoundOwns
  ]

sampleInstances :: Array InstanceInfo
sampleInstances =
  [ { typeId: 10, className: "NumExpr", classModule: "Hylograph.Expr.Expr", constraints: [] }
  , { typeId: 10, className: "StringExpr", classModule: "Hylograph.Expr.Expr", constraints: [] }
  , { typeId: 10, className: "BoolExpr", classModule: "Hylograph.Expr.Expr", constraints: [] }
  , { typeId: 10, className: "TrigExpr", classModule: "Hylograph.Expr.Expr", constraints: [] }
  , { typeId: 10, className: "Functor", classModule: "Data.Functor", constraints: [] }
  , { typeId: 10, className: "Apply", classModule: "Control.Apply", constraints: [] }
  , { typeId: 10, className: "Applicative", classModule: "Control.Applicative", constraints: [] }

  , { typeId: 20, className: "Semigroup", classModule: "Data.Semigroup", constraints: [] }
  , { typeId: 20, className: "Monoid", classModule: "Data.Monoid", constraints: [] }
  , { typeId: 20, className: "Show", classModule: "Data.Show", constraints: [] }

  , { typeId: 50, className: "Functor", classModule: "Data.Functor", constraints: [] }
  , { typeId: 50, className: "Foldable", classModule: "Data.Foldable", constraints: [] }
  , { typeId: 50, className: "Traversable", classModule: "Data.Traversable", constraints: [] }
  ]
