# Type Explorer

Visualize type relationships in PureScript codebases. Part of the Hylograph visualization toolkit.

## Overview

Type Explorer provides a "types-first" view of a codebase, revealing structure that may be hidden by the module system. It visualizes:

- **Type relationships**: How types relate through instances, usage, and module membership
- **Instance coverage**: Which types are well-specified (many instances) vs under-specified
- **Finally-tagless patterns**: The interpreter × expression class matrix

## Current Status

**Phase 1 Complete**: Project scaffolded with sample data.

Next phases will add:
- Real API integration with Minard backend
- Matrix view for interpreter × expression coverage
- Additional clustering strategies

## Building

```bash
# From repo root
make app-type-explorer

# Or directly
cd apps/type-explorer/frontend
spago build
spago bundle --platform browser --bundle-type app --outfile public/bundle.js
```

## Running

```bash
# Via Makefile
make serve-type-explorer PORT=8080

# Or directly
cd apps/type-explorer/frontend/public
python3 -m http.server 8080
```

Then open http://localhost:8080

## Architecture

```
apps/type-explorer/
├── frontend/
│   ├── src/
│   │   ├── Main.purs           # Entry point
│   │   ├── App.purs            # Main Halogen component
│   │   ├── Types.purs          # Core data types
│   │   ├── Views/
│   │   │   └── ForceGraph.purs # Force-directed visualization
│   │   └── Data/
│   │       └── Loader.purs     # API client (sample data for now)
│   ├── public/
│   │   ├── index.html
│   │   ├── styles.css
│   │   └── bundle.js           # Generated
│   └── spago.yaml
└── README.md
```

## Visualization

### Force Graph View

Types as nodes, relationships as links:

- **Node color** indicates maturity level (instance coverage)
  - Gold: High maturity (6+ standard instances)
  - Blue: Medium maturity (3-5 instances)
  - Gray: Low maturity (0-2 instances)
  - Purple: Type class definitions

- **Node size** varies by type kind (classes slightly larger)

- **Link color** indicates relationship type:
  - Green: Instance relationship
  - Pink: Superclass relationship
  - Orange: Type usage
  - Gray: Same-module relationship

- **Clustering** by package (configurable)

### Matrix View (Planned)

Interpreter × Expression class grid showing coverage.

## Data Model

```purescript
type TypeInfo =
  { id :: Int
  , name :: String
  , moduleName :: String
  , packageName :: String
  , kind :: TypeKind        -- Data, Newtype, TypeAlias, TypeClass
  , typeParameters :: Array String
  , instanceCount :: Int
  , maturityLevel :: Int    -- 0-8 based on core class instances
  }

type TypeLink =
  { source :: Int
  , target :: Int
  , linkType :: LinkType    -- InstanceOf, UsedIn, SameModule, etc.
  }
```

## Related

- [Hylograph Type System Analysis](../../docs/kb/reference/hylograph-type-system-analysis.md)
- [Type Explorer Plan](../../docs/kb/plans/type-explorer-plan.md)
- [Site Explorer](../minard/site-explorer/) - Similar force graph for routes
- [Minard](../minard/) - Code cartography (backend this will use)
