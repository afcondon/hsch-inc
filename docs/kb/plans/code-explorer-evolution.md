# Code Explorer Evolution Plan

**Status**: Active
**Created**: 2026-01-31
**Category**: plan
**Tags**: code-explorer, cli, visualization, halogen, developer-tools

## Vision

Code Explorer as a comprehensive codebase intelligence tool that addresses the "fog of war" problem in LLM-assisted development:

| Actor | Visibility Problem | CE Solution |
|-------|-------------------|-------------|
| Human | Changes are voluminous, hard to track | Visualization shows structure, patterns |
| LLM | Context window amnesia, no history | Queryable DB, authoritative answers |
| Both | Drift between intent and implementation | Live structural awareness |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Code Explorer                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   CLI (ce-loader)              Halogen App (CE2)            │
│   ┌─────────────┐              ┌─────────────────┐          │
│   │ Quick checks│              │ Visual explorer │          │
│   │ CI/CD hooks │◄────────────►│ Force graphs    │          │
│   │ Scripting   │   same DB    │ Tree views      │          │
│   └─────────────┘              │ Coupling viz    │          │
│         │                      └─────────────────┘          │
│         │                              │                     │
│         └──────────┬───────────────────┘                     │
│                    ▼                                         │
│           ┌───────────────┐                                  │
│           │   DuckDB      │                                  │
│           │ (ce-data.db)  │                                  │
│           └───────────────┘                                  │
│                    ▲                                         │
│                    │                                         │
│           ┌───────────────┐                                  │
│           │   Loaders     │                                  │
│           │ (incremental) │                                  │
│           └───────────────┘                                  │
│                    ▲                                         │
│                    │                                         │
│        ┌──────────┴──────────┐                              │
│        │                     │                               │
│   spago build           git history                          │
│   (output/)             (git log)                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Current State (2026-01-31)

### CLI (ce-loader) - Just Added
- `orphans` - Find modules not imported anywhere
- `orphan-groups` - Find disconnected module clusters
- Existing: `load`, `snapshot`, `list-projects`, `compute-metrics`

### Halogen App (CE2)
- Force graph visualization of module dependencies
- Package treemap
- Declaration browser
- Git churn overlay
- Coupling metrics display

### Database
- DuckDB with unified schema v3
- Multi-project, snapshot-based
- Full load takes ~30s for demo-website (1000 modules, 11k declarations)

## Planned Enhancements

### 1. Incremental Loading (High Priority)
**Problem**: Full snapshot takes 30s, discourages frequent updates
**Solution**:
- Track file mtimes, only reload changed modules
- Hook into `spago build` completion
- Watch mode for development

```bash
ce-loader watch --project demo-website  # Incremental updates on file change
```

### 2. CLI Query Expansion
**Problem**: More queries needed for codebase intelligence
**Candidates**:
- `unused-exports` - Exports never imported
- `coupling-report` - High coupling modules
- `churn-report` - Frequently changed files
- `cross-deps` - Cross-package dependency analysis
- `search` - Declaration search from CLI

### 3. CLI ↔ Visualization Links
**Problem**: CLI output is disconnected from visual understanding
**Solution**: CLI outputs links to relevant viz views

```bash
$ ce orphans --project demo-website
Found 7 orphan modules (3 groups)

View in explorer:
  http://localhost:8085/#/project/demo-website/orphans
  http://localhost:8085/#/project/demo-website/graph?highlight=orphans
```

### 4. Halogen App Improvements
**Problem**: Current viz is good but could be more actionable
**Candidates**:
- Orphan highlighting (red nodes)
- Disconnected cluster isolation
- "Problems" panel (like IDE)
- Side-by-side: graph + file tree
- Module detail panel with source preview
- Quick navigation from viz to code

### 5. Cross-Project Analysis
**Problem**: Can't see library usage across consuming projects
**Solution**:
- Load entire workspace as interconnected projects
- Query: "Which psd3-selection exports are unused by any demo?"
- Viz: Library module colored by usage frequency

### 6. LLM Integration
**Problem**: LLM has to run grep/find to understand codebase
**Solution**:
- MCP server exposing CE queries
- Claude can ask "what modules depend on X?" directly
- Structured responses, not grep output

```
Claude: <mcp_call tool="ce-query" query="orphans" project="demo-website"/>
Response: {modules: [...], count: 7, groups: [...]}
```

## Tomorrow's Session Focus

1. **Halogen app review** - What works, what's missing
2. **Incremental loading** - Key to making CE practical
3. **Orphan visualization** - Wire CLI findings into force graph
4. **Cross-project setup** - Load full workspace

## Related Documents

- `docs/kb/architecture/ce2-architecture.md` - CE2 frontend architecture
- `docs/kb/plans/ce2-links-hover-navigation.md` - Interaction improvements
- `showcases/corrode-expel/ce-database/schema/unified-schema.sql` - DB schema
- `showcases/corrode-expel/ce-database/loader/ce-loader.js` - CLI tool

## Open Questions

1. Should CE be a standalone tool or integrated into the Hylograph demo site?
2. How to handle very large codebases (10k+ modules)?
3. Should we publish ce-loader as an npm package?
4. Could CE analyze Haskell projects too? (Similar tooling exists)
