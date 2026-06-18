# Minard: Architectural Enforcement Features

**Category**: Plan
**Status**: Active (pre-release priority)
**Created**: 2026-03-05
**Related**: `plans/minard-future-work.md`, `ShapedSteer/ARCHITECTURE.md`

## Motivation

Minard currently visualizes code structure: modules, imports, declarations, dependency depth. But it treats all imports as equal — it has no concept of *intended* architecture. A dependency from a UI module to a data access module looks the same as any other edge.

This feature adds **architectural layer definitions** and **violation detection**, turning Minard from a passive code map into an active architectural fitness function. The immediate use case is enforcing ShapedSteer's layered architecture (8 layers, downward-only dependency rule), but the feature is general-purpose and applies to any project with architectural intent.

The term "architectural fitness function" comes from *Building Evolutionary Architectures* (Ford, Parsons, Kua): a measurable property of the system that guides its evolution. Minard becomes the measurement tool.

## What Ships

### Feature 1: Layer Configuration

**Input**: a config file at the project root defining layers and module assignments.

```yaml
# architecture.yml
project: shaped-steer
layers:
  - name: "Data Structures"
    order: 0
    pattern: "Data\\.(?!API).*"
    color: "#e8e8e8"
  - name: "Language"
    order: 1
    pattern: "Lang\\..*"
    color: "#d4e4f4"
  - name: "Build"
    order: 2
    pattern: "Build\\..*"
    color: "#d4f4d4"
  - name: "Unified DSL"
    order: 3
    pattern: "Unified\\..*"
    color: "#f4f4d4"
  - name: "DAG Core"
    order: 4
    pattern: "DAG\\..*"
    color: "#f4e4d4"
  - name: "Bridges"
    order: 5
    pattern: "Excel\\..*|Data\\.API"
    color: "#f4d4d4"
  - name: "Application"
    order: 6
    pattern: "App\\..*"
    color: "#e4d4f4"
  - name: "Demo"
    order: 7
    pattern: "Demo\\..*|Generated\\..*"
    color: "#f0f0f0"

rules:
  - type: direction
    constraint: downward_only
    description: "Layer N may import from layers 0..N, never N+1+"

exceptions:
  - module: "Unified.EvalAsync"
    may_import_from: [5]
    reason: "Effectful interpreter sitting at Layer 3/5 boundary"
```

**Format decision**: YAML over JSON (more readable for humans editing layer definitions). The loader already uses JSON for other config; adding a YAML parser (or converting to JSON) is minimal.

**Pattern matching**: module name regexes, not file paths. Module names are stable across refactors; file paths are not. Regex allows both simple (`DAG\..*`) and nuanced (`Data\.(?!API).*`) patterns.

**Unmatched modules**: any module not matching a pattern gets `layer: null` and is flagged as "unassigned" in the UI. This catches new modules that haven't been classified.

### Feature 2: Schema Changes

```sql
-- Layer definitions (per project/snapshot)
CREATE TABLE architecture_layers (
  id            INTEGER PRIMARY KEY,
  snapshot_id   INTEGER REFERENCES snapshots(id),
  name          VARCHAR NOT NULL,
  layer_order   INTEGER NOT NULL,
  pattern       VARCHAR NOT NULL,
  color         VARCHAR,
  UNIQUE(snapshot_id, layer_order)
);

-- Layer assignment on modules (computed during postload)
ALTER TABLE modules ADD COLUMN layer_id INTEGER REFERENCES architecture_layers(id);
ALTER TABLE modules ADD COLUMN layer_order INTEGER;

-- Rules
CREATE TABLE architecture_rules (
  id            INTEGER PRIMARY KEY,
  snapshot_id   INTEGER REFERENCES snapshots(id),
  rule_type     VARCHAR NOT NULL,  -- 'direction', 'forbidden', 'required'
  constraint    VARCHAR NOT NULL,
  description   VARCHAR
);

-- Exceptions
CREATE TABLE architecture_exceptions (
  id            INTEGER PRIMARY KEY,
  rule_id       INTEGER REFERENCES architecture_rules(id),
  module_name   VARCHAR NOT NULL,
  allowed_layers TEXT,   -- JSON array of layer orders
  reason        VARCHAR
);

-- Computed violations (materialized during postload)
CREATE TABLE architecture_violations (
  id              INTEGER PRIMARY KEY,
  snapshot_id     INTEGER REFERENCES snapshots(id),
  source_module   VARCHAR NOT NULL,
  target_module   VARCHAR NOT NULL,
  source_layer    INTEGER NOT NULL,
  target_layer    INTEGER NOT NULL,
  rule_id         INTEGER REFERENCES architecture_rules(id),
  severity        VARCHAR DEFAULT 'error'  -- 'error', 'warning', 'info'
);
```

### Feature 3: Loader Changes (Rust)

During the existing postload phase (after modules and imports are loaded):

1. **Read config**: look for `architecture.yml` in the project root. If absent, skip all layer features (backward compatible).
2. **Assign layers**: for each module, match its name against layer patterns in order. First match wins. Store `layer_id` and `layer_order` on the module row.
3. **Flag unassigned**: modules matching no pattern get `layer_order = NULL` and a warning.
4. **Compute violations**: for each import edge `(source_module, target_module)`:
   - Look up both modules' `layer_order`
   - If `source.layer_order < target.layer_order` (downward-only rule), it's a violation
   - Check exceptions table; if the source module has an exception allowing the target layer, skip
   - Insert into `architecture_violations`
5. **Summary stats**: count violations per layer pair, store as denormalized fields on the snapshot for quick dashboard access.

**Effort**: this is a straightforward extension of the existing postload pipeline. The module/import data is already loaded; this just adds classification and a join query.

### Feature 4: API Endpoints

```
GET /api/v2/architecture/layers?snapshot=<id>
  → Array of { name, order, color, module_count, violation_count }

GET /api/v2/architecture/violations?snapshot=<id>
  → Array of { source_module, target_module, source_layer, target_layer, rule, severity }

GET /api/v2/architecture/violations?snapshot=<id>&layer=<order>
  → Violations involving a specific layer (as source or target)

GET /api/v2/architecture/summary?project=<id>
  → Array of { snapshot_id, date, total_violations, modules_unassigned }
  (for drift tracking over time)
```

The PureScript server adds these as new routes alongside existing `/api/v2/modules`, `/api/v2/all-imports`, etc.

### Feature 5: Frontend — Layer Color Mode

Add `ArchitectureLayer` to the existing `ColorMode` sum type:

```purescript
data ColorMode
  = DefaultUniform
  | ProjectScope
  | FullRegistryTopo
  | ProjectScopeTopo
  | PublishDate
  | GitStatus
  | Reachability
  | ClusterView
  | ArchitectureLayer    -- NEW
```

When active:
- Modules colored by their layer's assigned color (from config)
- Unassigned modules colored distinctly (e.g., dashed border, grey)
- Legend shows all layers with their colors and module counts
- Treemap groups modules by layer (nested treemap: layer → modules)

This reuses the existing color mode infrastructure — the toolbar selector, the legend component, the `moduleColor` function pipeline.

### Feature 6: Frontend — Violation Overlay

When `ArchitectureLayer` color mode is active, violations are shown as an overlay on the dependency graph:

- **Violation edges**: red dashed lines between modules that violate layer rules
- **Violation badge**: small red count badge on modules with violations (like git status badges)
- **Status bar**: "3 architecture violations" or "0 violations" at the top of the scene
- **Click-through**: clicking a violation edge shows the specific import statement (source location from CST spans, already in the schema)

This overlay works on:
- The treemap view (badges on module cells)
- The dependency graph view (red edges)
- The module detail view (list of violations involving this module)

### Feature 7: Frontend — Module Size Warnings

Independent of layers but architecturally relevant:

- Modules exceeding a configurable LOC threshold (default: 500) get a warning badge
- Visible in treemap (the module cell is already sized by LOC, but a badge makes the threshold explicit)
- Config in `architecture.yml`:
  ```yaml
  thresholds:
    module_loc_warning: 500
    module_loc_error: 1000
    max_exports: 20
  ```

### Feature 8: Drift Tracking

When multiple snapshots exist for a project:

- **Violations timeline**: simple line chart showing `total_violations` per snapshot date
- **Layer health table**: per-layer violation counts across snapshots (improving/worsening)
- **New violations**: diff between current and previous snapshot — "3 new violations since last snapshot"

This uses the existing snapshot infrastructure. The chart is a simple HATS line/area chart (Hylograph already has these primitives).

## What Does NOT Ship (Scope Boundaries)

- **Automatic layer inference** from code structure — too heuristic-dependent, better to have humans define intent
- **Coupling metrics** (efferent/afferent, Martin's stability) — useful but a separate feature; layer enforcement is higher priority
- **Cross-project architectural rules** — only within a single project for now
- **Fix suggestions** — Minard shows violations, it doesn't propose refactors (that's the reviewer agent's job)

## Implementation Order

Build these in dependency order; each step is independently shippable:

| Step | Feature | Depends on | Shippable alone? | Effort |
|------|---------|-----------|-----------------|--------|
| 1 | Config file parsing | — | No (invisible without UI) | Half day |
| 2 | Schema + loader layer assignment | Step 1 | Yes (queryable via SQL) | 1 day |
| 3 | Violation computation in loader | Step 2 | Yes (queryable via SQL) | Half day |
| 4 | API endpoints | Steps 2-3 | Yes (curl-testable) | Half day |
| 5 | Layer color mode | Step 4 | Yes (visible in UI) | 1 day |
| 6 | Violation overlay | Steps 4-5 | Yes (visible in UI) | 1-2 days |
| 7 | Module size warnings | Step 4 | Yes (independent) | Half day |
| 8 | Drift tracking | Steps 3-4 | Yes (independent) | 1 day |

**Total**: ~5-7 days of focused work. Steps 1-5 are the minimum viable feature (~3 days). Steps 6-8 are refinements.

## Testing Strategy

1. **Loader**: ingest ShapedSteer with the `architecture.yml` config. Verify the 4 known violations from `ARCHITECTURE.md` are detected: DAG.Core→Lang.Eval, Data.API placement, App.D3 raw FFI, Lang.Pattern→Sankey.
2. **API**: curl the endpoints, verify JSON shape matches frontend expectations.
3. **Frontend**: visual check — do layers color correctly? Do violation edges appear? Does the legend render?
4. **Drift**: create two snapshots (before and after fixing a violation), verify the timeline shows the change.

## Config File Location

The `architecture.yml` lives in the **target project** (e.g., `ShapedSteer/architecture.yml`), not in Minard. Minard discovers it during ingestion the same way it discovers `spago.yaml` — by scanning the project root.

This means:
- Each project owns its own architectural rules
- Rules are version-controlled alongside the code
- Different projects can have different layer schemes
- A project without `architecture.yml` gets no layer features (fully backward compatible)

## Relationship to ShapedSteer Intensive

This feature is a **pre-work deliverable** for the ShapedSteer intensive. The timeline:

1. Build Minard layer enforcement (Steps 1-5, ~3 days)
2. Write ShapedSteer's `architecture.yml` (from existing `ARCHITECTURE.md`, ~1 hour)
3. Ingest ShapedSteer into Minard, verify violations match expectations
4. Begin ShapedSteer intensive with architectural enforcement in place

During the intensive, the reviewer agent checks Minard's violation count before approving merges. Drift tracking (Step 8) provides weekly visibility into whether the architecture is improving.

---

*This plan should be implemented before Minard's public release, as architectural enforcement is a compelling differentiator for code cartography tools.*
