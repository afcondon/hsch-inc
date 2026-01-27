---
title: "CE2 State Machine Analysis"
category: reference
status: active
tags: [ce2, code-explorer, state-machine, navigation]
created: 2026-01-25
summary: Shorthand naming system and click transition matrix for CE2 views.
---

# CE2 State Machine Analysis

## View Naming System

### Galaxy Level (All 568 packages)

| Code | Name | Description |
|------|------|-------------|
| A | Galaxy Treemap | Blueprint theme, packages as treemap cells |
| B | Galaxy Beeswarm | Blueprint theme, packages as circles, full registry |

### Solar Level (Project packages, scope-filtered)

| Code | Name | Description |
|------|------|-------------|
| C1 | SolarSwarm Trans | Bubblepacks, transitive scope |
| C1M | Trans Matrix | Transitive scope, matrix overlay |
| C1C | Trans Chord | Transitive scope, chord overlay |
| C2 | SolarSwarm Deps | Bubblepacks, project+deps scope |
| C2M | Deps Matrix | Project+deps scope, matrix overlay |
| C2C | Deps Chord | Project+deps scope, chord overlay |
| C3 | SolarSwarm Proj | Bubblepacks, project-only scope |
| C3M | Proj Matrix | Project-only scope, matrix overlay |
| C3C | Proj Chord | Project-only scope, chord overlay |

### Neighborhood Level (Single package focus)

| Code | Name | Description |
|------|------|-------------|
| D | Pkg Neighborhood | Circlepack: deps \| focal \| dependents |

### Module Level (Single package's modules)

| Code | Name | Description |
|------|------|-------------|
| E | Module Treemap | Paperwhite theme, modules by LOC |
| EM | Module Matrix | Module import adjacency matrix |
| EC | Module Chord | Module import chord diagram |
| F | Module Beeswarm | Flow overlay on treemap |

### Panel State

| Code | Name | Description |
|------|------|-------------|
| P | Panel | Slide-out panel (open/closed, which module) |

## Click Transition Matrix

### Clickable Elements

- **pkg** : Package (cell/circle/bubblepack outer)
- **mod** : Module (inner circle/treemap cell/chord arc/matrix cell)
- **scope-A** : Scope → All
- **scope-T** : Scope → Transitive
- **scope-D** : Scope → Project+Deps
- **scope-P** : Scope → Project Only
- **view-S** : View → Swarm/Treemap (primary)
- **view-M** : View → Matrix
- **view-C** : View → Chord
- **nav+** : Forward/+ button
- **nav←** : Back button

### Transition Table

```
VIEW        | pkg         | mod        | scp-A | scp-T | scp-D | scp-P | vw-S | vw-M  | vw-C  | nav+  | nav←
------------|-------------|------------|-------|-------|-------|-------|------|-------|-------|-------|------
A  Treemap  | highlight   | -          | -     | -     | -     | -     | -    | -     | -     | →B    | -
B  Beeswarm | →D+panel    | -          | =     | →C1   | →C2   | →C3   | -    | -     | -     | →C1   | →A
C1 Trans    | →D+panel    | panel      | →B    | =     | →C2   | →C3   | =    | →C1M  | →C1C  | -     | →B
C1M Matrix  | ?           | ?          | →B    | =     | →C2M  | →C3M  | →C1  | =     | →C1C  | -     | →B
C1C Chord   | ?           | ?          | →B    | =     | →C2C  | →C3C  | →C1  | →C1M  | =     | -     | →B
C2 Deps     | →D+panel    | panel      | →B    | →C1   | =     | →C3   | =    | →C2M  | →C2C  | -     | →B
C2M Matrix  | ?           | ?          | →B    | →C1M  | =     | →C3M  | →C2  | =     | →C2C  | -     | →B
C2C Chord   | ?           | ?          | →B    | →C1C  | =     | →C3C  | →C2  | →C2M  | =     | -     | →B
C3 Proj     | →D+panel    | panel      | →B    | →C1   | →C2   | =     | =    | →C3M  | →C3C  | -     | →B
C3M Matrix  | ?           | ?          | →B    | →C1M  | →C2M  | =     | →C3  | =     | →C3C  | -     | →B
C3C Chord   | ?           | ?          | →B    | →C1C  | →C2C  | =     | →C3  | →C3M  | =     | -     | →B
D  Neighbor | →D'+panel   | -          | -     | -     | -     | -     | -    | -     | -     | →E    | →C?
E  ModTree  | -           | panel      | -     | -     | -     | -     | =    | →EM   | →EC   | →F    | →D
EM ModMat   | -           | ?          | -     | -     | -     | -     | →E   | =     | →EC   | →F    | →D
EC ModChord | -           | ?          | -     | -     | -     | -     | →E   | →EM   | =     | →F    | →D
F  ModBee   | -           | panel?     | -     | -     | -     | -     | -    | -     | -     | -     | →E
```

### Legend

- `=` stays in current view
- `-` not available in this view
- `?` undefined/unclear behavior
- `→X` navigates to view X
- `→X+panel` navigates and opens panel
- `panel` opens panel without navigation

## Observations

### State Space Size

1. **Galaxy level**: 2 views (A, B)
2. **Solar level**: 3 scopes × 3 views = 9 sub-states (C1-C3, each with M/C variants)
3. **Neighborhood level**: 1 view (D), but parameterized by focal package
4. **Module level**: 4 views (E, EM, EC, F), parameterized by package
5. **Panel**: 2 states (open/closed) × N modules

### Open Questions

1. **Back from D is ambiguous** - which C variant should we return to? Need to track "came from" state.

2. **Matrix/Chord clicks undefined** - what happens when clicking a cell/arc in matrix or chord views? Options:
   - Navigate to package/module
   - Open panel
   - Highlight related elements
   - Nothing (display only)

3. **Panel state orthogonal?** - Is panel open/closed independent of view state, or should certain transitions close the panel?

4. **Scope in neighborhood?** - Should D have scope filtering, or is it always "focal + direct deps + direct dependents"?

5. **Event bubbling** - Module clicks in bubblepacks also trigger package clicks (parent). Need stopPropagation or explicit handling.

### Simplification Opportunities

1. **Flatten C-level?** - Instead of 9 states, treat scope and view as orthogonal state variables within a single "SolarSwarm" scene.

2. **Consistent back behavior** - Always go to parent scene, lose sub-state (scope resets to default).

3. **Panel as overlay** - Panel doesn't affect navigation state, just overlays current view.

## Notes

- Treemap at minimap scale is still legible (observed in UI bug where treemap rendered in toggle panel)
- Could use PSD3 to visualize this state machine as a force-directed graph
