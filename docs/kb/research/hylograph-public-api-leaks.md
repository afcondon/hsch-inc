---
title: Hylograph public API leaks — dead node types and the Internal namespace
category: research
status: implemented
tags: [hylograph, api-surface, anti-synergy, hylograph-selection, hylograph-simulation, dead-code, technical-debt]
created: 2026-07-27
summary: Two findings surfaced while building hylograph-graph-json — dead node/link types in ForceEngine.Types, and Hylograph.Internal.* serving as the de-facto public API with ~470 external imports. Both fixed and published on 2026-07-28 (hylograph-selection 0.5.2, hylograph-simulation 0.6.0, hylograph-simulation-halogen 0.5.1). Includes a correction to the original diagnosis and a postscript on detection tooling.
---

# Hylograph public API leaks

Two findings from building `hylograph-graph-json` (see
`kb/plans/hylograph-graph-json.md`). Both are ecosystem-level rather than
specific to that package, and both cost real time before they were
understood. This is the first concrete output of the anti-synergy survey.

## 1. `ForceEngine.Types` node/link types are dead, and dangerous

`Hylograph.ForceEngine.Types` defines `SimNode`, `SimLink`, `RawLink` and
`SimulationState`. **Nothing in the ecosystem imports any of them.**

```bash
grep -rn "import Hylograph.ForceEngine.Types" --include="*.purs" . \
  | grep -i "simnode\|rawlink\|simlink"     # → no results
```

They are byte-identical duplicates of the types in
`Hylograph.Kernel.D3.Types` (`hylograph-d3-kernel`), down to a duplicated
`mergeSimulationState` in each package's `Setup.purs`. They look like a
fork left behind by the kernel separation, never deleted.

**Why this is worse than ordinary dead code.** The name is exactly what
you search for, and it is wrong:

- `Hylograph.ForceEngine.Types.SimNode extra` = `{ x, y, vx, vy, index :: Int | extra }` — 0 importers
- `Hylograph.Kernel.D3.Types.SimNode extra` = the same shape, in the kernel package
- `Hylograph.ForceEngine.Simulation.SimulationNode r` = `{ id :: Int, x, y, vx, vy, fx, fy | r }` — **what `Sim.setNodes` actually consumes**

The dead one is the first hit when you go looking for "the simulation node
type", it has the more inviting name, and it is subtly incompatible:
`index` where the live type has `id`, and no `fx`/`fy`.

Three separate codebases have independently written
`type SimNode = SimulationNode` locally to get the name they wanted —
`CodeExplorer/minard/frontend/src/Types.purs:34`, and both visual tests
inside `hylograph-simulation` itself. So within the defining package, the
tests alias around its own exported type.

`hylograph-graph-json`'s `toSim` was written against the dead type and
passed 11 test groups while being impossible to feed to `Sim.setNodes`.
Only compiling a worked example caught it.

Note `Hylograph.Simulation` (the package's top-level module) already
deliberately points people at the right one:

```purescript
import Hylograph.ForceEngine.Simulation (SimulationNode) as SimNodeExports
```

**Recommendation.** Delete `SimNode`, `SimLink`, `RawLink` and
`SimulationState` from `Hylograph.ForceEngine.Types`, and drop them from
`Hylograph.ForceEngine`'s re-export list (lines 42–45). The rest of that
module — `ForceSpec`, the force configs, `defaultManyBody` and friends —
is heavily used and stays. Zero importers means this is a non-breaking
deletion for every consumer we can see.

## 2. `Hylograph.Internal.*` is the de-facto public API

`ElementType` is required for every single `elem` call, and is reachable
only through:

```purescript
import Hylograph.Internal.Element.Types (ElementType(..))
```

It is not an implementation detail. It is the closed vocabulary of things
you can draw — `Circle | Rect | Path | Line | Polygon | Text | Group |
SVG | Defs | ... | Div | Span | Table | ...`. The module's own header
explains how it got there:

> "Shared types used by both HATS and the legacy Selection API. Extracted
> from Internal.Selection.Types to decouple HATS from Selection."

So it inherited the `Internal` prefix from where it was extracted, rather
than by anyone deciding it should be private.

**This is not a small leak.** Import statements reaching into
`Hylograph.Internal.*` from outside `hylograph-selection`:

| Module | Imports |
|--------|---------|
| `Hylograph.Internal.Element.Types` | 175 |
| `Hylograph.Internal.Behavior.Types` | 78 |
| `Hylograph.Internal.Attribute` | 70 |
| `Hylograph.Internal.Selection.Types` | 60 |
| `Hylograph.Internal.Transition.Types` | 30 |
| `Hylograph.Internal.Types` | 23 |
| `Hylograph.Internal.Behavior.FFI` | 18 |
| others (Transition.Manager, FFI, Element.Operations, …) | ~20 |

Roughly 470 statements, across `ShapedSteer/minard-for-nix`, `warrant`,
`signal-box`, `CodeExplorer`, `purescript-polyglot`, the registry-dev
dashboard, and now `hylograph-graph-json`'s own example. Consumers are
also split across two paths for the same type — 60 imports still name
`Internal.Selection.Types`, which no longer exists in the current source
and only resolves for repos pinned to an older `hylograph-selection`.

Three of these are FFI modules, which is a stronger smell again:
application code reaching directly into `Behavior.FFI` and `Internal.FFI`.

**The fix is already half-built.** `Hylograph.HATS` establishes exactly
this pattern at line 61:

```purescript
  , module ReExportHighlight
...
import Hylograph.Internal.Behavior.Types
  (DragConfig, ZoomConfig, HighlightClass(..), TooltipTrigger(..)) as ReExportHighlight
```

`ElementType` — the one type nobody can avoid — was simply left out of it.

**Recommendation, in order of cost:**

1. **Now, additive and non-breaking:** re-export `ElementType(..)` and
   `RenderContext(..)` from `Hylograph.HATS`, alongside the existing
   `ReExportHighlight` block. New code stops reaching inside; the 175
   existing imports keep working.
2. **Next:** audit what else consumers reach for — `Attribute` at 70 and
   `Transition.Types` at 30 are plainly public vocabulary too — and
   re-export the genuinely public parts.
3. **Later, breaking:** move the public types out of `Internal.*`
   altogether (`Hylograph.Element.Types`), leaving deprecated re-exports
   behind. Only worth doing once (1) and (2) have absorbed the churn.

Until at least (1) lands, `/fp-police`'s D1 rule ("application code should
use public APIs") will keep flagging violations that consumers cannot
avoid — which trains people to ignore the rule. That is the real cost.

It also undercuts the onboarding goal directly: a newcomer following the
docs to their first visualization is made to import an `Internal` module.

## Correction to the diagnosis above — 2026-07-28

The section above says `ElementType` "inherited the `Internal` prefix" from
where it was extracted. That is not what happened, and the real story is
more useful.

Those modules' own headers read:

> **Internal module** — use the public API in `Hylograph.Behavior`.

and likewise for `Hylograph.Transition` and `Hylograph.Selection`. **None
of those modules were ever written.** The code was correctly marked
internal, the documentation correctly redirected the reader, and the
destination did not exist.

So the ~470 imports were not a boundary being ignored. They were the only
door in the building. Nobody was doing anything wrong; the API was simply
unfinished, and had been for long enough that the workaround became the
convention.

Worth generalising: a "misplaced boundary" and an "unfinished boundary"
look identical from the outside — both present as consumers reaching into
`Internal`. They call for opposite responses. The first wants the marker
removed; the second wants the promised thing built. Reading the module
header was what distinguished them, and it took thirty seconds.

## What was done — 2026-07-28

Five vocabulary modules promoted to public homes, old paths retained as
deprecating re-export shims:

| Was | Now |
|-----|-----|
| `Hylograph.Internal.Element.Types` | `Hylograph.Element.Types` |
| `Hylograph.Internal.Attribute` | `Hylograph.Attribute` |
| `Hylograph.Internal.Transition.Types` | `Hylograph.Transition.Types` |
| `Hylograph.Internal.Behavior.Types` | `Hylograph.Behavior.Types` |
| `Hylograph.Internal.Types` | `Hylograph.Foreign.Types` |

The migration rule is "delete `.Internal`", mechanical enough to script,
with one deliberate exception: `Hylograph.Types` would have been far too
generic for a handful of D3 FFI handles. Those handles are opaque but
genuinely public — `Datum_` and `Index_` appear in the signature of every
callback a consumer writes.

`Hylograph.HATS` now also re-exports `ElementType(..)` and
`RenderContext(..)`, so the common case needs no second import. It already
did this for `DragConfig`, `ZoomConfig`, `HighlightClass` and
`TooltipTrigger`; the one type nobody can avoid had been left out.

Because the shims preserve the exact public surface, the change is purely
additive — a **patch** bump, not a breaking one. Every consumer's
`>=0.5.0 <0.6.0` range stayed valid and no downstream repo needed
coordinating.

`test/Test/DeprecatedPaths.purs` guards it: it imports every deprecated
path by its old name and asserts *in the type checker* that old and new
denote the same declarations rather than lookalikes. Writing it also
flushed out several arities that would otherwise have been guessed wrong —
`Behavior`, `AnimatedValue` and `D3Selection_` are parameterised,
`AttrSource` is not, `Selector` is phantom-typed, and `defaultZoom` takes
two arguments.

The dead types went separately, and that one *was* breaking:
`hylograph-simulation` 0.6.0. Removing a public export is breaking by the
letter of semver even when it provably has no importers, because neither
the registry nor any consumer can verify the claim. Seven repos had their
ranges widened to `>=0.5.0 <0.7.0` beforehand.

`hylograph-simulation-halogen` turned out to be a cascade point: it is
itself published and depended on `hylograph-simulation <0.6.0`, so anyone
wanting both would have been stuck. Widening its range required its own
release (0.5.1) to mean anything.

## Published — 2026-07-28

| Package | Version |
|---------|---------|
| `hylograph-selection` | 0.5.2 |
| `hylograph-simulation` | 0.6.0 |
| `hylograph-simulation-halogen` | 0.5.1 |

Two of the three declared `license: MIT` while shipping no licence text —
five releases each with the claim unbacked. Files added before publishing.

## Publishing does not make a version reachable

The most operationally surprising thing to come out of the release.

**Package sets pin versions and override dependency ranges.** A consumer on
`packageSet: registry: 77.13.1` resolves whatever that set pins, regardless
of the bound in its own `spago.yaml`. Set 77.13.1 pins
`hylograph-selection: 0.5.1`; so does the newest published set, 80.0.0,
which predates these releases.

So the range widening across seven repos was **necessary but not
sufficient**. It prevents a conflict when the set advances. It does not
advance anything. Nothing picks up 0.6.0 or 0.5.2 until a new set is cut.

The visible consequence: `hylograph-graph-json`'s worked example still
imports `Hylograph.Internal.Element.Types`, because it resolves 0.5.1 which
lacks the re-export. An `extraPackages` override would force it, and was
deliberately not used — that trades a visible comment for an invisible
obligation to remember to remove it, which is the exact debt pattern this
document exists to record. The import carries a comment saying what blocks
it and when to delete it.

## Status / Next Steps

- [x] Re-export `ElementType(..)` / `RenderContext(..)` from `Hylograph.HATS`
- [x] Delete the dead node/link/state types from `Hylograph.ForceEngine.Types`
- [x] Version bumps and republish — all three live on the registry
- [ ] **Remaining `Internal.*` leakage: the FFI modules.** Application code
      still imports `Internal.Behavior.FFI` (18), `Internal.FFI` (6) and
      `Internal.Transition.FFI` (2) for things like `attachZoom_`,
      `arcGenerator_` and the `setForce*_` family. This is a *different*
      problem from the one fixed here — those are genuinely internal and
      genuinely foreign; consumers reach for them because no public wrapper
      exists. Missing API, not misplaced API, and it wants wrappers rather
      than a move.
- [ ] `Internal.Element.Operations.createElementWithNS` (6 imports) — same
      question, smaller.
- [ ] Delete the deprecation shims, but only once the ecosystem has
      migrated, and delete `Test.DeprecatedPaths` in the same commit.
- [ ] Migrate consumers off the deprecated paths as they are touched; the
      rewrite is mechanical (`Hylograph.Internal.X` → `Hylograph.X`).

---

# Postscript: what tooling would have caught this?

Asked after the fact, and the answer is not "add a rule to fp-police".

## fp-police structurally cannot catch it

fp-police is a **syntactic lint**: grep patterns evaluated against one file
at a time. Deadness is a **whole-program reachability question**. No amount
of per-file pattern matching answers it.

Its one nominally relevant rule, D4, greps for the literal strings
`unused`, `dead code`, `no longer used` — which finds only dead code
somebody has already *labelled*. That is exactly backwards: labelled dead
code is the harmless kind. The dangerous kind looks alive.

The compiler cannot help either, and correctly so. PureScript warns on
unused *local* bindings and unused imports, but never on an unused
*exported* declaration — because for a library, any export may have a
consumer the compiler cannot see. That is the right default and it is
precisely the blind spot.

`API-INDEX.md` holds half the answer already: every top-level declaration
in the ecosystem. The missing half is a **reference** index. Declarations
minus references is the query. Caveat: these are published registry
packages, so the world is not formally closed — any such tool should report
"no references found in this ecosystem", never "dead".

## Would it stand out in Minard? No — and the reason is instructive

Minard already computes the right *metric*. `declaration_coupling` carries
`external_caller_count`, and zero callers is exactly the dead-code signal.

But the edge table feeding it is `function_calls` —
`(caller_module_id, caller_name) → (callee_module, callee_name)`. **Calls.**

A type is never called. `SimNode` appears in type signatures and import
lists, never in a call graph. So in Minard's reference graph *every* type
has zero incoming edges, and a genuinely dead type is indistinguishable
from a load-bearing one. Types are present as nodes in `declarations` and
absent from the edges entirely.

So the instinct "dead types should be highlighted more than dead functions"
lands somewhere sharper than expected: **it is not a weighting problem, it
is a missing edge kind.** You cannot weight what you do not measure.

The fix is cheaper than it sounds, because the data is already there.
`declarations.type_ast` stores the structured type AST per declaration.
Walking those ASTs for type-constructor mentions yields a `type_references`
edge table with no new extraction pass over source — the same way
`function_calls` gives call edges. Once that exists, `external_caller_count`
means something for types, and dead types become isolated nodes in the
force layout exactly as one would hope.

## Yes, dead types deserve higher severity — and the worst case is narrower

The severity argument holds, with a refinement. The highest-severity case
is specifically an **exported type alias inside a live module**:

1. **Invisible at module granularity.** `ForceEngine.Types` is imported all
   over the ecosystem for `ForceSpec` and `defaultManyBody`. The module is
   emphatically alive. The dead declarations hide inside it. Any
   module-level analysis reports nothing.
2. **Types are what you read to orient.** A dead function is inert — nobody
   calls it, it does nothing. A dead type is *actively consulted* by anyone
   trying to understand the domain, and it miseducates.
3. **Aliases have no nominal identity.** A `type` synonym is a name over a
   shape. Two identical shapes in different packages do not conflict; they
   quietly coexist. That is how `SimNode` came to exist twice.
4. **The failure is delayed.** A wrong call fails at the call site. A wrong
   type fails at the *join* — arbitrarily far away, after eleven green
   tests.

## Two detectors worth more than deadness

**Duplicate structure.** The real harm was never that `SimNode` was unused
— it was that two packages defined the same shape under the same name.
With `type_ast` already stored, "find structurally identical type
declarations across packages" is a straightforward query, and it would have
fired *before* the type went dead — at the moment of the kernel split,
when the fix was trivial.

**Repeated local workarounds.** Three codebases independently wrote
`type SimNode = SimulationNode` to get the name they wanted, including both
visual tests inside the defining package. Each instance is locally
reasonable; no reviewer would object to any one of them. Collectively they
are a loud signal that the upstream name is wrong. *N independent
aliases/wrappers over the same API* is computable from declaration data
alone and points at API defects rather than merely dead ones.

This is the genuinely agent-era signature, and worth being precise about.
Leaving duplicates behind after a refactor is an ancient failure — the
kernel separation would have shed this debris at any pace, under any
authorship. What changes with agent-paced work is not the kind of mistake
but its *distribution*: not one large error, but the same small error made
independently N times, each instance locally defensible, none of them
visible to a reviewer looking at a single diff. Tooling that hunts for
repetition-of-small-workarounds is therefore better matched to how the debt
actually accumulates than tooling that hunts for large mistakes.

## Status / Next Steps (postscript)

- [ ] Add a `type_references` edge table to Minard, derived from the
      already-stored `declarations.type_ast`
- [ ] Extend `declaration_coupling` to count type references, so
      `external_caller_count` is meaningful for types
- [ ] Weight dead exported type aliases in live modules above dead functions
- [ ] Duplicate-structure detector over `type_ast` across packages
- [ ] Repeated-local-alias detector — N codebases wrapping the same API
- [ ] Consider a reference index alongside `API-INDEX.md`; report
      "unreferenced in this ecosystem", never "dead"
