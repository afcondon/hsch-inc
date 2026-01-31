# Git State Audit: 2026-01-31

## Status: Active Reference

## Summary

Audit of git state across all repos in PSD3-Repos, revealing significant uncommitted work, orphaned feature branches, and coordination failures from the `/feature` skill workflow.

**Key finding:** The deployed version on MacMini works. Worst case is everything is running on AST (pre-HATS), which is a sound architecture.

## The Situation

### Root Cause

Premature breakup of monorepo into ~30 separate git repos, combined with `/feature` skill attempting to coordinate virtual feature branches across repos. The coordination didn't work reliably, leaving:

- Uncommitted changes across many repos
- Feature branches created but not merged
- Stashed work from abandoned branches
- Worklog documentation referencing commits that don't exist

### Quantified Damage

| Category | Count |
|----------|-------|
| Total uncommitted files | ~1,700+ |
| Repos with uncommitted changes | 25+ |
| Repos on `feature/hats-migration` | 8 |
| Orphaned feature branches in monorepo root | 4 |
| Stashes in hylograph-selection | 2 |

## Detailed Inventory

### Core Libraries

| Repo | Branch | Uncommitted | Stashes | Unpushed |
|------|--------|-------------|---------|----------|
| hylograph-selection | `feature/hats-migration` | 51 | 2 | 0 |
| hylograph-simulation | main | 1 | 0 | 0 |
| hylograph-simulation-halogen | main | 893 | 0 | 4 |
| hylograph-layout | main | 0 | 0 | 1 |
| hylograph-graph | main | 1 | 0 | 0 |

**Note:** hylograph-simulation-halogen's 893 uncommitted files are likely build artifacts (`output/`, `.spago/`).

### Monorepo Root Feature Branches

```
feature/d3-reduction
feature/heterogeneous-ast
feature/remove-ord-constraint-updatejoin
feature/unified-transitions
```

Plus 20 uncommitted files, 1 stash, 3 unpushed commits on main.

### Showcases on `feature/hats-migration`

| Showcase | Uncommitted |
|----------|-------------|
| allergy-outlay | 5 |
| corrode-expel | 7 |
| emptier-coinage | 3 |
| hypo-punter | 548 |
| psd3-arid-keystone | 0 (clean) |
| psd3-tilted-radio/purescript-psd3-tidal | 16 |

### hylograph-selection Stashes

```
stash@{0}: On feature/hats-v2: HATS work in progress
stash@{1}: On feature/recursive-join: WIP recursive-join and other changes
```

These are from different branches than the current `feature/hats-migration`.

### hylograph-selection Feature Branches

```
* feature/hats-migration  (current, 4 commits ahead of main)
  feature/hats-v2         (separate branch, unknown state)
  main
```

Commits on feature/hats-migration not in main:
```
b39b2b1 Remove dead code: PSD3.purs and .legacy files
8c005ed Hylograph rename: psd3 → hylograph + JS FFI path fixes
8e9bcf8 HATS migration: Embedding Explorer + brush throttling
b943862 WIP: HATS core improvements and new interpreters
```

## HATS Implementation Issues Discovered

During this audit, we discovered that the current HATS implementation has a critical gap:

1. **`bindDatum` never called**: The FFI has `bindDatum` to set `element.__data__`, but InterpreterTick.purs never imports or calls it.

2. **Drag behavior broken**: `simulationDragNested` reads `element.__data__.node` but since data is never bound, drag silently fails.

3. **Any datum-retrieving behavior affected**: Click handlers, tooltips, or any behavior that needs to retrieve the datum from a DOM element at event time won't work.

**What HATS closures DO handle:**
- Static attributes (values captured at template time)
- Thunked behaviors where the handler captures all needed data
- Coordinated highlighting (uses thunked identify functions)

**What HATS closures DON'T handle:**
- Behaviors that need to read datum from DOM at event time
- External code (like simulation drag) that expects D3-style `__data__`

## Recovery Options

### Option 1: Commit Everything As-Is
Snapshot current state across all repos, accept the mess, move forward.

### Option 2: Selective Recovery
1. Identify which uncommitted changes are valuable
2. Commit those with proper messages
3. Discard build artifacts and stale changes
4. Merge or close feature branches

### Option 3: Nuclear - Trust Deployed Version
1. The MacMini deployment works
2. Clone fresh from deployed state
3. Abandon all uncommitted local work
4. Start clean

## Recommendations

1. **Don't panic** - Deployed version works, AST is sound architecture
2. **Document before touching** - This file captures current state
3. **Decide on HATS** - Either fix the gaps or roll back to AST
4. **Consolidate repos** - Consider whether the multi-repo structure is working

## Related Documents

- `docs/worklog/2026-01-31.md` - Today's session log
- `docs/kb/architecture/psd3-interpreter-systems.md` - Interpreter architecture
- `docs/kb/plans/hats-v2-design.md` - (to be created) HATS redesign proposal
