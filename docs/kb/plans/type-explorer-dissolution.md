---
title: "TypeExplorer Dissolution into Minard"
category: plan
status: proposed
tags: [type-explorer, minard, code-explorer, refactor]
created: 2026-02-20
summary: Dissolve TypeExplorer as a separate frontend project, migrating useful views back into Minard and moving the Counterexamples article to the new Ecosystem showcase site.
---

# TypeExplorer Dissolution into Minard

## Context

TypeExplorer was created as a separate frontend project within CodeExplorer to prototype type-centric views of PureScript codebases. It has its own spago.yaml, its own bundle, its own port (3002), and its own dependency set.

With hindsight, the separation creates more friction than value:
- Duplicate dependency management (separate spago.yaml tracking hylograph versions)
- Separate deployment target
- No shared state with Minard's backend (duplicate data loading in Loader.purs)
- The "useful views" (force graph, matrix, type class grid) are really just additional lenses on the same codebase data that Minard already serves

Meanwhile, the Counterexamples article — the most polished TypeExplorer output — is evolving into something that belongs on a dedicated showcase site, not inside a code exploration tool.

## What Moves Where

### To Minard (as additional views/lenses)

| View | Current File | Value |
|------|-------------|-------|
| **Force Graph** | `Views/ForceGraph.purs` | Type relationship visualization — directly useful for exploring a codebase's type landscape |
| **Type Class Grid** | `Views/TypeClassGrid.purs` | Card grid of type classes with method count donuts — useful overview lens |
| **Matrix** | `Views/Matrix.purs` | Interpreter × Expression coverage — specific to finally-tagless architecture but valuable |
| **Splitscreen** | `Views/TypeClassesSplit.purs` | Matrix + Grid combined — carries over if both parents do |

These views consume type information from the Minard API. Currently TypeExplorer has a stub `Loader.purs` with sample data; in Minard they'd connect to the real backend.

### To Ecosystem Showcase Site

| View | Current File | Destination |
|------|-------------|-------------|
| **Counterexamples** | `Views/CounterexamplesGrid.purs` | Flagship exhibit on the new PureScript Libraries Ecosystem site |

The counterexamples article uses curated static data (not codebase-derived), so it doesn't need Minard's backend. It's a showcase piece, not a code exploration tool.

### Discarded

| Item | Reason |
|------|--------|
| `TypeExplorer.App` (Halogen shell) | Minard has its own app shell |
| `TypeExplorer.Main` | Entry point replaced by Minard's |
| `TypeExplorer.Types` | Merge relevant types into Minard's type definitions |
| `Loader.purs` sample data | Replaced by real API calls |
| Separate `spago.yaml` | Dependencies merge into Minard's |
| Port 3002 | No longer needed |
| `public/index.html`, `styles.css` | Minard has its own |

## Migration Steps

### Step 1: Dependency Alignment

Ensure Minard's spago.yaml already has (or can accept) the dependencies TypeExplorer uses:
- `hylograph-selection >=0.2.0` (already there — Minard drove the upgrade)
- `hylograph-simulation >=0.2.0` (already there)
- `hylograph-graph >=0.1.0` (already there)
- `sigil >=0.2.0` (already there for Minard's own sigil usage)

No new dependencies needed — TypeExplorer's deps are a subset of Minard's.

### Step 2: Move View Files

Copy the view `.purs` files into Minard's source tree under an appropriate module path:

```
minard/src/CE2/Viz/TypeGraph.purs       ← ForceGraph.purs
minard/src/CE2/Viz/TypeClassGrid.purs   ← TypeClassGrid.purs (already exists, merge)
minard/src/CE2/Viz/TypeMatrix.purs      ← Matrix.purs
```

Adjust module names and imports. Replace sample data loading with Minard API calls.

### Step 3: Wire into Minard's View Switcher

Minard's frontend has a view selection mechanism. Add entries for the new views so they appear in the navigation.

### Step 4: Move Counterexamples to Ecosystem Site

The `CounterexamplesGrid.purs` and its sigil.css additions move to the new ecosystem showcase project (see `purescript-ecosystem-site.md`). This happens when that project is bootstrapped.

### Step 5: Remove TypeExplorer

- Delete `type-explorer/frontend/` directory
- Remove port 3002 from the deploy skill
- Update CLAUDE.md to remove TypeExplorer references
- Update docker-compose if TypeExplorer had a service entry

### Step 6: Update Documentation

- Update `type-explorer-plan.md` status to `dissolved`
- Update `code-explorer-evolution.md` to reflect the consolidation
- Session log entry

## Timing

This is not urgent. The dissolution should happen when:
1. The Ecosystem site has a home for the Counterexamples article
2. There's a natural Minard session where adding new views makes sense
3. Both can happen independently — the views can move to Minard before the Ecosystem site exists (counterexamples just stays in TypeExplorer until it has a new home)

## Risks

- **View integration effort**: the TypeExplorer views assume a Halogen app shell and their own CSS. Minard uses a different structure. Some adaptation needed.
- **CSS conflicts**: TypeExplorer's styles.css has rules that may clash with Minard's. Need to namespace or merge carefully.
- **Data shape differences**: TypeExplorer's `TypeInfo`, `TypeLink` types may not match Minard's existing type representations exactly.

None of these are hard problems, just integration work.
