# Type Explorer Implementation Plan

**Category**: plan
**Status**: active
**Created**: 2026-02-05
**Tags**: type-explorer, visualization, hylograph, minard

## Overview

Type Explorer is a browser-based tool for visualizing type relationships in PureScript codebases. It provides a "types-first" view that reveals structure hidden by the module system.

## Goals

1. Visualize type relationships across the hylograph-* packages
2. Show the Interpreter × Expression matrix (finally-tagless coverage)
3. Reveal type families, instance coverage gaps, and architectural patterns
4. Eventually integrate into a suite of code exploration tools sharing Minard's backend

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Type Explorer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Force Graph │  │   Matrix    │  │  (Future)   │     │
│  │    View     │  │    View     │  │   Views     │     │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘     │
│         │                │                              │
│         └────────┬───────┘                              │
│                  │                                      │
│         ┌───────┴────────┐                              │
│         │   App.purs     │  Halogen State Management    │
│         │  (Component)   │                              │
│         └───────┬────────┘                              │
│                 │                                       │
│         ┌───────┴────────┐                              │
│         │  Loader.purs   │  API Client                  │
│         └───────┬────────┘                              │
└─────────────────┼───────────────────────────────────────┘
                  │ HTTP
┌─────────────────┼───────────────────────────────────────┐
│                 │           Minard Backend              │
│         ┌───────┴────────┐                              │
│         │  /api/v2/...   │  REST API                    │
│         └───────┬────────┘                              │
│                 │                                       │
│         ┌───────┴────────┐                              │
│         │    DuckDB      │  Type Data                   │
│         └────────────────┘                              │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
apps/type-explorer/
├── frontend/
│   ├── src/
│   │   ├── Main.purs              # Halogen entry point
│   │   ├── App.purs               # Main component, view switching
│   │   ├── Types.purs             # Core data types
│   │   ├── Views/
│   │   │   ├── ForceGraph.purs    # Force-directed type graph
│   │   │   └── Matrix.purs        # Interpreter × Expression matrix
│   │   └── Data/
│   │       └── Loader.purs        # Minard API client
│   ├── public/
│   │   ├── index.html
│   │   └── styles.css
│   └── spago.yaml
└── README.md
```

## Data Model

### Core Types

```purescript
-- A type declaration from the codebase
type TypeInfo =
  { id :: Int
  , name :: String
  , moduleName :: String
  , packageName :: String
  , kind :: TypeKind           -- Data, Newtype, TypeAlias, TypeClass
  , typeParameters :: Array String
  , instances :: Array InstanceInfo
  , maturityLevel :: Int       -- 0-8 based on core class instances
  }

-- An instance relationship
type InstanceInfo =
  { className :: String
  , classModule :: String
  , constraints :: Array String
  }

-- Link between types
type TypeLink =
  { source :: Int              -- TypeInfo id
  , target :: Int              -- TypeInfo id
  , linkType :: LinkType
  }

data LinkType
  = InstanceOf                 -- Type implements Class
  | UsedIn                     -- Type appears in signature
  | SameModule                 -- Types in same module
  | Superclass                 -- Class extends Class

-- For the matrix view
type InterpreterInfo =
  { name :: String
  , moduleName :: String
  , implementedClasses :: Array String
  }

type ExpressionClassInfo =
  { name :: String
  , moduleName :: String
  , methods :: Array String
  }
```

### Cluster Configuration

```purescript
data ClusterStrategy
  = ByPackage                  -- One cluster per package
  | ByMaturity                 -- Group by instance coverage level
  | ByTypeKind                 -- Data vs Newtype vs Class
  | ByUsage                    -- Frequently used vs rarely used

type ClusterConfig =
  { strategy :: ClusterStrategy
  , clusterCount :: Int
  , positions :: Map String Point  -- Cluster name → center position
  }
```

## API Endpoints (New)

### GET /api/v2/types

Returns all type declarations for specified packages.

```json
{
  "types": [
    {
      "id": 1,
      "name": "Selection",
      "moduleName": "Hylograph.Internal.Selection.Types",
      "packageName": "hylograph-selection",
      "kind": "data",
      "typeParameters": ["state", "parent", "datum"],
      "instances": [
        {"className": "Functor", "classModule": "Data.Functor"}
      ],
      "maturityLevel": 6
    }
  ],
  "count": 260
}
```

### GET /api/v2/type-links

Returns relationships between types.

```json
{
  "links": [
    {"source": 1, "target": 45, "linkType": "instance_of"},
    {"source": 1, "target": 2, "linkType": "same_module"}
  ],
  "count": 450
}
```

### GET /api/v2/interpreter-matrix

Returns the finally-tagless interpreter × expression class matrix.

```json
{
  "interpreters": [
    {"name": "Eval", "moduleName": "...", "implementedClasses": ["NumExpr", "StringExpr", ...]}
  ],
  "expressionClasses": [
    {"name": "NumExpr", "moduleName": "...", "methods": ["add", "sub", "mul", ...]}
  ],
  "matrix": [
    [true, true, true, false],  // Eval row
    [true, true, false, false]  // English row
  ]
}
```

## Implementation Phases

### Phase 1: Project Scaffold (This Session)
- [x] Create plan document
- [ ] Create directory structure
- [ ] Set up spago.yaml with dependencies
- [ ] Create Types.purs with core types
- [ ] Create Main.purs entry point
- [ ] Create minimal App.purs
- [ ] Create index.html
- [ ] Add Makefile targets

### Phase 2: Force Graph View
- [ ] Adapt ForceGraph.purs from Site Explorer
- [ ] Implement node rendering (types as circles)
- [ ] Implement link rendering (multiple link types)
- [ ] Add cluster forces (ForceXGrid/ForceYGrid)
- [ ] Add interactive sidebar (click node → details)
- [ ] Color coding by maturity level

### Phase 3: API Integration
- [ ] Add /api/v2/types endpoint to Minard server
- [ ] Add /api/v2/type-links endpoint
- [ ] Implement Loader.purs to fetch data
- [ ] Handle loading states in UI

### Phase 4: Matrix View
- [ ] Create Matrix.purs component
- [ ] Fetch interpreter-matrix data
- [ ] Render as heatmap/grid
- [ ] Add click interactions (cell → instance details)
- [ ] Highlight row/column on hover

### Phase 5: Polish & Integration
- [ ] View switching in App.purs
- [ ] Filter controls (by package, by kind)
- [ ] Search functionality
- [ ] Docker container setup
- [ ] Integration with edge router

## Dependencies

```yaml
dependencies:
  - aff
  - affjax
  - affjax-web
  - arrays
  - console
  - effect
  - either
  - foldable-traversable
  - halogen
  - hylograph-selection
  - hylograph-simulation
  - maybe
  - ordered-collections
  - prelude
  - strings
  - tuples
  - web-dom
  - web-html
```

## Force Configuration (from Site Explorer)

```purescript
simConfig :: SimConfig
simConfig =
  { forces:
      [ Link { distance: 60.0, strength: 1.0, iterations: 1 }
      , ForceXGrid 0.08    -- Cluster separation
      , ForceYGrid 0.05    -- Vertical centering
      , Collide { radius: 15.0, strength: 0.7, iterations: 1 }
      , ManyBody { strength: -100.0, theta: 0.9, minDistance: 1.0, maxDistance: 500.0 }
      ]
  , alpha: { initial: 1.0, min: 0.001, decay: 0.0228, target: 0.0 }
  , velocityDecay: 0.4
  }
```

## Color Scheme

| Element | Color | Meaning |
|---------|-------|---------|
| Node (high maturity) | Gold #c9a227 | Well-specified types |
| Node (medium maturity) | Blue #4a90d9 | Partial instance coverage |
| Node (low maturity) | Gray #8a8a8a | Under-specified types |
| Node (type class) | Purple #7b4aa0 | Type class definitions |
| Link (instance) | Green #4caf50 | Instance relationship |
| Link (usage) | Orange #ff9800 | Type usage in signature |
| Link (module) | Light gray #cccccc | Same-module relationship |

## Related Documents

- `docs/kb/reference/hylograph-type-system-analysis.md` - Type analysis this tool visualizes
- `apps/minard/site-explorer/` - Source for force graph patterns
- `apps/minard/ARCHITECTURE.md` - Backend architecture
