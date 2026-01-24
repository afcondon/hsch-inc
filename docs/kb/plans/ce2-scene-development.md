# CE2 Scene Development Plan

**Status**: Active
**Created**: 2026-01-24
**Category**: Plan

## Philosophy

### Exploratory Programming
We're discovering the right abstractions through implementation. Expect refactoring. The `ScaleLevel` type encodes the intention but the parameterization types will emerge from exploration.

### Component Focus
Two reasons for strong component boundaries:
1. **Fractal domain** - Components reusable across scale levels (a treemap of packages looks like a treemap of modules)
2. **Claude context** - Well-bounded components lead to better AI assistance outcomes

### Implementation Order
1. Implement views individually (largest → smallest scale)
2. Get each view working standalone
3. Add transitions between views last
4. Refactor to unify patterns discovered during implementation

### Library-First Development
CE2 is both a showcase demo and an integration test for the PSD3 libraries. Principles:

1. **Leverage the library to the max** - Use existing primitives before writing custom code. If something is awkward, that's a signal to improve the library.

2. **Extend/fix the library when needed** - Don't work around library limitations in application code. Fix the library, then use it properly.

3. **Exploit the declarative AST** - The `A.Tree` type is data, not code. Use this for:
   - **Snippets**: Reusable tree fragments (e.g., `labeledCircle`, `tooltipGroup`)
   - **Parameterization**: Functions that return trees, composed into larger trees
   - **Readability**: Visualization code should read like a description, not imperative steps

4. **DRY through composition** - If two views share structure, extract the common AST fragment. The tree algebra (`withChildren`, `withAttributes`) enables this naturally.

```purescript
-- Example: reusable snippet
labeledCircle :: forall r. String -> (r -> Number) -> A.Tree r
labeledCircle label radiusFn =
  A.elem Group []
  `A.withChildren`
    [ A.elem Circle [ Attr.attr "r" radiusFn showNumD ]
    , A.elem Text [ Attr.attrStatic "textContent" label ]
    ]

-- Composed into larger tree
packageNode :: A.Tree PackageNode
packageNode =
  A.elem Group [ Attr.attr "transform" translateFn idD ]
  `A.withChildren`
    [ labeledCircle "pkg" _.radius  -- reused snippet
    , moduleIndicator                -- another snippet
    ]
```

---

## Parameterization Axes

### Axis 1: Color Scheme (existing, needs refactoring)

Current implementation is 4 discrete options:
| Option | Description |
|--------|-------------|
| `default` | Standard colors |
| `project` | Highlight packages in our project |
| `topo` | Color by topological layer in PACKAGE SET |
| `projectTopo` | Color by topological layer in PROJECT |

**Tech debt**: This is really a product of two variables:
- `highlighting :: Maybe HighlightSet` (none, project, custom)
- `colorBy :: ColorScheme` (uniform, topoLayer, publishDate, loc, ...)

Many more color schemes to explore - defer refactoring until we know what we need.

### Axis 2: Treemap Contents (new)

What to render inside each treemap cell:

| Option | Description |
|--------|-------------|
| `PackageCircle` | Single circle per package (current) |
| `Nothing` | Empty cell, just the rect |
| `ModuleCircles` | Circle per module in package |
| `BubblePack` | Packed circles: package outer, modules inner |
| `Text` | Package/module name as text |

### Axis 3: Treemap Theme (new)

Base colors that distinguish scale levels:

| Scale | Background | Text | Rationale |
|-------|------------|------|-----------|
| Galaxy (registry) | Blueprint blue | White | Technical/architectural feel |
| Solar System (packages) | Paperwhite | Black | Clean, readable |
| Planet (module) | Dataviz beige | Black | Warm, detailed |

### Axis 4: Beeswarm Data Filter (new)

Which nodes to include:

| Option | Count | Description |
|--------|-------|-------------|
| `AllPackageSet` | ~568 | All packages in registry |
| `AllProject` | ~139 | All packages our project uses |
| `LocalOnly` | ~17 | Only local packages (ce2-, psd3-) |

### Axis 5: Beeswarm Node Rendering (new)

How to render each node:

| Option | Description |
|--------|-------------|
| `Circle` | Simple circle, radius by metric |
| `BubblePack` | Packed group: outer = package, inner = modules |

---

## Task Breakdown

### Phase 1: Treemap Parameterization

- [ ] **1.1** Extract treemap cell renderer as component
- [ ] **1.2** Add `CellContents` sum type: `PackageCircle | Empty | ModuleCircles | BubblePack | Text`
- [ ] **1.3** Implement `Empty` variant (simplest)
- [ ] **1.4** Implement `Text` variant
- [ ] **1.5** Implement `ModuleCircles` variant (requires module data per package)
- [ ] **1.6** Implement `BubblePack` variant (composition of package + modules)
- [ ] **1.7** Add theme parameter (blueprint/paperwhite/beige)

### Phase 2: Beeswarm Parameterization

- [ ] **2.1** Extract beeswarm node renderer as component
- [ ] **2.2** Add data filter parameter to beeswarm view
- [ ] **2.3** Implement `LocalOnly` filter
- [ ] **2.4** Add `NodeRendering` sum type: `Circle | BubblePack`
- [ ] **2.5** Implement `BubblePack` rendering (modules inside package circle)

### Phase 3: Module-Level Views

Lift everything to work with modules, not just packages:

- [ ] **3.1** Parameterize visualization code to accept `Graph a` instead of hardcoded package graph
- [ ] **3.2** Create module dependency graph from import data
- [ ] **3.3** Module treemap (modules as cells)
- [ ] **3.4** Module beeswarm (modules as nodes)
- [ ] **3.5** Define module-internal categories: `Types | Instances | FFI | PureFunctions | EffectfulFunctions`
- [ ] **3.6** Bubblepack inside module showing declaration categories

### Phase 4: Within-Module View

- [ ] **4.1** Declaration-level treemap/beeswarm
- [ ] **4.2** Further categorization: `HasTest | NoTest`, `Exported | Internal`
- [ ] **4.3** Call graph visualization within module

### Phase 5: Transitions (deferred)

Only after all views work standalone:

- [ ] **5.1** Design transition state machine
- [ ] **5.2** Implement fade/morph between adjacent scales
- [ ] **5.3** Handle non-adjacent jumps (e.g., galaxy → planet)

---

## Type Sketches (WIP, will evolve)

```purescript
-- Cell contents for treemaps
data CellContents
  = CellCircle          -- Single circle
  | CellEmpty           -- Just the rect
  | CellModuleCircles   -- Circles for each module
  | CellBubblePack      -- Nested pack layout
  | CellText            -- Name label only

-- Theme for visual distinction
data ViewTheme
  = BlueprintTheme      -- Blue bg, white text (galaxy)
  | PaperwhiteTheme     -- White bg, black text (solar system)
  | BeigeTheme          -- Warm bg, black text (planet)

-- Beeswarm data source
data BeeswarmScope
  = FullPackageSet
  | ProjectPackages
  | LocalPackages

-- Node rendering style
data NodeStyle
  = SimpleCircle
  | PackedBubble

-- Eventually: unified config
type ViewConfig =
  { scope :: BeeswarmScope
  , nodeStyle :: NodeStyle
  , cellContents :: CellContents
  , theme :: ViewTheme
  , colorScheme :: ColorScheme
  , highlight :: Maybe HighlightSet
  }
```

---

## Open Questions

1. **Module categories**: Is `Types | Instances | FFI | Functions` the right decomposition? Need to explore what data we have.

2. **Color scheme refactoring**: When do we bite the bullet and make it properly compositional?

3. **Graph abstraction**: How generic should the visualization code be? `forall a. Graph a -> ...` or specific `PackageGraph` / `ModuleGraph` types?

4. **Bubblepack nesting**: How deep does nesting go? Package → Module → Declaration → ???

---

## Success Criteria

- [ ] Can switch treemap contents without code changes (config only)
- [ ] Can switch beeswarm scope without code changes
- [ ] Same component renders packages OR modules (parameterized)
- [ ] Each scale level visually distinct via theming
- [ ] No FFI for any new visualization code
- [ ] Visualization code is declarative and readable (AST composition, not imperative D3)
- [ ] Reusable AST snippets extracted (at least 3 shared across views)
- [ ] Any library gaps discovered are fixed in the library, not worked around
