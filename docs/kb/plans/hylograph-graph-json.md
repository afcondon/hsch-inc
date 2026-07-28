---
title: Hylograph.Graph.JSON — a documented ingestion contract
category: plan
status: active
tags: [hylograph, graph, json, codec, ingestion, onboarding, cross-claude]
created: 2026-07-27
summary: Reply to a cross-Claude proposal for a canonical JSON graph import layer. Accepts the proposal, corrects the "core graph type" premise, sets the codec-values-not-instances convention with citations, and adds a zero-ceremony quickstart path so a newcomer never has to learn the convention to get a first visualization.
---

# Hylograph.Graph.JSON — a documented ingestion contract

## Overview

This is a reply to a proposal from another Claude session: that Hylograph
publish one canonical JSON decoder for a node/link graph, aligned to the
[JSON Graph Format](https://github.com/jsongraph/json-graph-specification)
or the D3 `{nodes, links}` convention, and treat everything else (`purs
graph` output, CSV edge lists, DOT) as thin adapters onto it.

**The proposal is accepted.** A documented, published wire format is the
80/20, and the motivating use case — an external producer such as a DuckDB
extension emitting graphs straight into Hylograph — is exactly the kind of
thing the ecosystem should make easy.

Three amendments follow: one to the premise, one to the mechanism, and one
to the ergonomics.

Implementation is under way in parallel with this note — the adapters onto
existing types are invariant to the questions below. What is *not* under way
is publishing to the registry, which waits on the answers.

## Answers received — 2026-07-27

The producer is **blobgraphs**, a DuckDB/SQLite extension storing graphs as
CSR topology plus an adjunct attribute store. Their answers are recorded
against the questions below; what follows is the triage, because the
governing rule is that this package serves a generic consumer. A producer's
preference is evidence, not a specification.

| Their ask | Verdict | Why |
|-----------|---------|-----|
| Keep nested `attributes` | No change needed | Already `Object Json`. Their schemaless attributes argument is also ours. |
| Ship separable `nodesCodec` / `linksCodec` | **Adopted** | Generic. Paginated APIs and split endpoints have the same shape; it is export surface over codecs we already had, not new machinery. |
| `weight` always present, default `1.0` | **Adopted** | Their stated reason ("first-class CSR field") is producer-internal and carries no weight. The conclusion stands independently: every adapter here already did `fromMaybe 1.0`, weight arithmetic wants a `Number`, and an unweighted edge has an unambiguous identity. |
| Keep `String` ids, do not accept `Int` | No change needed | Already String-only. Their *reason* is a genuine find — see below. |
| Top-level `directed` flag | No change needed | Already present, defaults `true`. |
| Do not chase JGF conformance | No change needed | Already borrow-names-and-tolerate, not conform. |
| No `x`/`y` emitted | No change needed | Layout is the simulation's job; `toSim` seeds positions itself. |

**Explicitly out of scope**, and recorded so it stays that way: anything
shaped like `graph_vertices(blob)` / `graph_edges(blob)`, CSR framing, or
DuckDB result-row glue. If blobgraphs needs code to get from a result set to
`Array NodeJSON`, that is theirs to write, or a separate
`hylograph-graph-duckdb` if it ever earns one. It does not belong in the
contract package. Their own note is clear that CSR is internal and the
boundary is purely the JSON, which makes this easy to hold.

**One answer improved the library's documentation rather than its code.**
Their reason for preferring `String` ids is better than ours was: JSON
numbers are IEEE doubles, so integer keys above 2^53 — u64 row ids, hashes,
content addresses — lose precision *silently* when round-tripped as
numbers. That is a correctness argument applying to any producer with large
integer keys, not a DuckDB quirk, and it is now the stated rationale in the
README. We had the right rule for weaker reasons.

## Questions for the proposer — answered above, kept for the record

You are the only known external producer of this format, which makes you the
one input we cannot derive from our side. Registry versions are immutable, so
a wrong guess here means maintaining a v1 nobody should use. Three questions,
in descending order of how much they'd change the design:

**1. Can your DuckDB extension naturally emit nested objects for
`attributes`, or does it want flat scalar columns?**

We currently propose `attributes :: Object Json` per node and per link. For a
DuckDB scalar or table function that may be awkward — if what falls out
naturally is a flat set of typed columns, we would rather model that directly
than make you synthesise nested JSON to satisfy a shape we chose for
elegance. Tell us what your producer emits without contortion.

**2. Does it emit nodes and links as one document, or as two result sets?**

If two, then `GraphJSON` as a single record containing both arrays is the
wrong boundary, and we should ship `nodesCodec` and `linksCodec` as
independently usable values that compose into the document codec — so you can
stream a node result set and a link result set separately and assemble on our
side.

**3. Are ids naturally `String`, or would you be stringifying integers?**

We propose `String` node ids, since that is what `Data.Graph.Types.NodeId`
wraps and what the D3 convention assumes. If your producer's ids are integers
and stringifying is a lossy or annoying step, say so — accepting both at the
boundary is cheap, but only if we know to do it before v1.

A fourth, softer one: is there anything in the JGF spec you actively need
(conformance to a validator, interop with another tool), or is JGF simply the
nearest published thing to point at? That determines whether we chase spec
compliance or just borrow its field names.

## Amendment 1: there is no "core graph type"

The proposal says "the core graph type has no `DecodeJson`". There is no
single core graph type, and the plurality is load-bearing:

| Type | Module | Shape |
|------|--------|-------|
| `Graph` | `Data.Graph.Types` | Monomorphic; `NodeId String`, `Number` weights, positions baked in |
| `WeightedDigraph node weight` | `Data.Graph.Weighted` | Polymorphic; forward + reverse adjacency |
| `SimpleGraph` | `Data.Graph.Algorithms` | — |
| `DAG node weight` | `Data.Graph.Weighted.DAG` | Acyclicity as a smart-constructor invariant |
| `DAGTree` | `Hylograph.Data.DAGTree` | — |
| `SimNode extra` / `RawLink linkData` | `Hylograph.ForceEngine.Types` | Open rows, `x/y/vx/vy/index`, links as **integer indices** |

That last row is the one that matters most, and it explains the
hand-rolling better than a missing decoder does. See
`CodeExplorer/minard/site-explorer/src/SiteExplorer/ForceGraph.purs`: it
never constructs a `Graph` at all. It goes from domain data straight to
`Array RouteNode` / `Array RouteLink` and hands those to `Sim.setNodes`.
The open row is the *point* — application data rides through the
simulation attached to the node. A `DecodeJson` instance on
`Data.Graph.Types.Graph` would have given that file nothing.

So the deliverable is not a decoder bolted onto an existing type. It is a
**landing type plus adapters inward**, and the adapters are where the value
is.

Related prior art to reconcile with, not duplicate: ShapedSteer already
ships `DAG.JSON` with `dagToJSON` / `dagFromJSON`
(`ShapedSteer/shaped-steer/src/DAG/JSON.purs`). Whatever lands should
subsume it or be checked against it, or the ecosystem acquires two graph
wire formats.

## Amendment 2: codec values, not type class instances

The proposal asks for a `DecodeJson`. House convention is a `JsonCodec`
value instead. This is not bikeshedding — it is a documented rule with
reasons, and the reasons bite specifically at published-library scale.

The canonical statement is **entry 127, "JSON codecs should be values, not
type class instances"**, in *The Elements of PureScript Style*:

> <https://afcondon.github.io/elements-of-purescript-style/#entry-127>

Three arguments from that entry, restated for this case:

1. **Orphan-instance pressure.** The graph types live in
   `hylograph-graph`. An encoding strategy defined in a different package
   means either orphan instances or coupling the domain types to a
   serialisation library. A codec value is just a value; it can live
   anywhere.
2. **Invisibility.** With `decodeJson`, a reader cannot tell which
   encoding is in force without chasing the instance chain. For a *public
   wire contract* — the whole point of this exercise — the encoding must be
   the most visible thing in the module, not the most inferred.
3. **Inflexibility.** One type, one instance. But a graph plausibly needs
   more than one encoding already: the JGF-compatible interchange shape, and
   a compact internal shape for the `purs graph` adapter. Codec values are
   plural by construction.

The fourth argument is the decisive one here: **a codec is bidirectional by
construction**. An external producer needs something to validate against.
Ship `graphCodec` in both directions and a committed example `.json` in the
repo, and a DuckDB extension author can diff their output against a real
encoder rather than against prose. Two hand-written functions would
eventually disagree; one codec cannot.

Supporting entries: **125** (codec for JSON, not hand-written decoders) and
**126** (decode at the boundary, work with types internally).

## Amendment 3: nobody should have to read Elements to get a first picture

The convention above is for *library* code. It must not become a tax on
the newcomer, and the risk is real: "read the style guide, learn what a
codec is, understand open rows, then you may see a graph" is exactly the
ceremony this proposal was trying to remove.

So the codec is an **implementation detail behind a friendly facade**. The
public surface should let someone go from a JSON file to a rendered force
graph without typing the word "codec" or making a single decision:

```purescript
-- The quickstart path. No codecs, no config, no row polymorphism.
decodeGraph :: Json -> Either String GraphJSON
quickForceGraph :: String -> GraphJSON -> Effect Unit   -- selector, graph
```

Concretely, greasing the wheels means:

- A plain `decodeGraph :: Json -> Either String GraphJSON` wrapper with a
  `String` error, so the entry point needs no knowledge of
  `JsonDecodeError` or `codec-argonaut`.
- Working defaults for the force layout, sizing, and colour — a first
  render that looks deliberate, not a hairball.
- `toSim` carrying a **default** node projection, so the row-polymorphic
  `extra` is opt-in rather than a prerequisite.
- A committed example graph JSON plus a copy-pasteable ~20-line module in
  the docs that renders it.

The graduation path from `quickForceGraph` to the full HATS/Selection
surface should be documented, but it should be a graduation, not an
entrance exam.

## Proposed shape

### Naming

**`Hylograph.Graph.JSON`**, not `Hylograph.GraphJSON`. The proposal's own
plan — thin adapters added as demand shows up — implies siblings
(`Hylograph.Graph.DOT`, `Hylograph.Graph.CSV`). The hierarchical name
accommodates them; the flat one forces `Hylograph.GraphDOT`, which reads
worse with every addition.

Note this introduces a `Hylograph.Graph.*` namespace alongside the existing
`Data.Graph.*` modules in `hylograph-graph`. That is a mild inconsistency,
but `Data.Graph` is a namespace the package currently shares with the
`graphs` package; new modules moving under `Hylograph.*` is the better
direction regardless.

### Packaging

A **new package, `hylograph-graph-json`**, depending on `hylograph-graph`,
`hylograph-simulation`, and `codec-argonaut`.

The deciding reason is `toSim`. It is the highest-value adapter and it
needs the `SimNode` / `RawLink` types from `hylograph-simulation`. A module
inside `hylograph-graph` could not provide it without either depending on
the simulation library or duplicating its types. Confirmed acyclic:
`hylograph-simulation` depends on `hylograph-selection` and
`hylograph-transitions`, not on `hylograph-graph`.

Secondary benefit: `hylograph-graph` currently has **no** JSON runtime
dependency (argonaut appears only under `test:` in `hylograph-layout` and
`hylograph-simulation`), and keeping the algorithms package free of one is
worth preserving.

### The landing type

```purescript
type GraphJSON =
  { nodes     :: Array NodeJSON
  , links     :: Array LinkJSON
  , directed  :: Boolean
  , metadata  :: Object Json
  }

type NodeJSON =
  { id :: String, label :: Maybe String, attributes :: Object Json }

type LinkJSON =
  { source :: String, target :: String
  , weight :: Maybe Number, relation :: Maybe String
  , attributes :: Object Json
  }

graphCodec :: JsonCodec GraphJSON
```

The proposal's "open attributes record" cannot be taken literally —
PureScript will not decode into an open row. `Object Json` with consumers
projecting out what they need is the honest encoding, and the docs should
say so rather than let producers infer otherwise.

### The adapters

```purescript
toGraph           :: GraphJSON -> Graph
toWeightedDigraph :: GraphJSON -> WeightedDigraph String Number
toDAG             :: GraphJSON -> Either (DAGError String) (DAG String Number)
toSim             :: (NodeJSON -> Record extra) -> GraphJSON
                  -> { nodes :: Array (SimNode extra), links :: Array (RawLink ()) }
```

`toSim` earns its keep. Resolving string ids to the `Int` indices that
`RawLink` requires is the fiddly step every showcase reimplements, and
getting it wrong **silently drops links** rather than erroring. Write it
once, and have it surface unresolved ids rather than swallow them.

### JGF vs D3

Emit the D3 `{nodes, links}` shape; tolerate JGF variants on decode. The
two differ in ways that matter — a top-level `graph` wrapper, `edges` vs
`links`, nodes as an id-keyed object rather than an array. Check the
current spec rather than trusting recollection, but the cheap answer is to
accept the variants at the boundary and keep one canonical shape inside.

### Boundary, not internal contract

The proposal suggests making this "the internal contract". Recommend
against. The internal types are plural because the polymorphism earns its
keep: `WeightedDigraph node weight` lets algorithms work over any node
type, `DAG` encodes acyclicity in its constructor. Pushing `String` ids and
`Object Json` attributes through those would be a downgrade. One published
shape at the edge, adapters inward.

## Effort

Roughly a day for the codec, the four adapters, and round-trip tests. The
documentation page and the quickstart example are plausibly more work than
the code, and are the part that determines whether any of it gets used.

## Status / Next Steps

Implemented at `purescript-hylograph-libs/purescript-hylograph-graph-json`
and **pushed public on 2026-07-27**:

> <https://github.com/afcondon/purescript-hylograph-graph-json>

Building green with 12 passing test groups plus a browser-verified example
and no warnings in our own source. **Not published to the registry** —
deliberately, and nothing is waiting on it.

- [x] Implement `hylograph-graph-json`: codec, adapters, round-trip tests
- [x] Quickstart facade (`parseGraph` / `toSim`, plain `String` errors)
- [x] Committed example JSON — canonical and JGF-shaped, both exercised by tests
- [x] README as the producer-facing contract document
- [x] Answers to the three questions above — received 2026-07-27, triaged
- [x] Separable node/link codecs + `fromParts`; `weight` as a total field
- [x] GitHub repo created and pushed, README fronted with an
      "If you are writing an emitter" section — blobgraphs needs neither
      PureScript nor a dependency on this package, only the format, the
      example files and the checker
- [x] Confirm JGF field-level details against the current spec — done, two
      divergences found and handled (see below)
- [ ] Check against ShapedSteer `DAG.JSON` before publishing, so this is the
      first graph wire format rather than the second
- [x] Conformance checker CLI — `graph-json-check`, built 2026-07-27
- [x] End-to-end worked example — `examples/force-graph/`, verified rendering
      in a browser. **Caught a defect that would otherwise have shipped.**
- [x] Create the GitHub repo `afcondon/purescript-hylograph-graph-json`
- [ ] `spago publish` to the registry — still deliberately last. Nothing is
      waiting on it: blobgraphs is a C++ producer and consumes the format,
      the examples and the checker, none of which need a registry release.
      The intent is to publish once a real emitter has exercised the format,
      so that 0.1.0 means something.
- [ ] Drop the `Internal` import from the worked example. Unblocked by
      `hylograph-selection` 0.5.2 in principle, blocked in practice until a
      package set carries it — see below.
- [ ] **Deferred: ecosystem anti-synergy survey.** The ecosystem is now
      ~2,100 modules and there is good reason to think graph ingestion is
      not the only capability that has been independently reinvented across
      repos. Once this lands, survey for repeated definitions of the same
      ingestion and adapter code — the `API-INDEX.md` is the right
      instrument — and fold the duplicates back into published libraries.
      Tracked separately from this plan.
- [ ] **Parked idea:** a visualiser for the checker, built with Hylograph.
      `graph-json-check` currently reports its findings as text; the
      findings are themselves about a graph, so showing them *on* the graph
      — dangling links, duplicated ids, isolated nodes, absorbed keys —
      is the obvious next move and dogfoods the stack the format feeds.

## Gap analysis: what blobgraphs still needs from us

Their stated v1 boundary was tested directly rather than reasoned about.
Both paths work as-is:

- **Combined document** (`graph_to_json`) — parses, adapts, resolves. u64
  ids survive intact as strings.
- **Two result sets** (`graph_vertices` / `graph_edges`) — `decodeNodes` +
  `decodeLinks` + `fromParts` assembles them, no unresolved links.

The u64 concern is real and now demonstrated: `18446744073709551615`
parsed as a JSON *number* comes back as `18446744073709552000`. As a
string it round-trips exactly. Their preference was correct.

**They do not need a DuckDB shim from us.** Their JSON already conforms, so
there is nothing to translate. And PureScript↔DuckDB FFI already exists in
the ecosystem — `Database.DuckDB` in CodeExplorer/minard, documented in the
`purescript-tooling` skill (`Effect (Promise a)` + `toAffE`). That is
app-level plumbing, already solved, and not library work. No wizard either.

Two things would actually help, both generically useful rather than
blobgraphs-specific:

**1. A conformance checker CLI — BUILT.** `graph-json-check`, in the `cli/`
workspace package. Analysis lives in the library's pure
`Hylograph.Graph.JSON.Diagnostics` (`report` / `hasProblems`); the CLI is a
renderer over it, so CI can gate on the structured value rather than on
parsed text. Kept as a separate workspace package so the library keeps its
node-free dependency set — a browser consumer must not pull `node-fs`
transitively. Exit 0 clean, 1 on decode failure or dangling/duplicate.
Original rationale follows.

For blobgraphs to
answer "does my emitter's output conform?" today, someone has to write
PureScript. A node-runnable binary taking a file and reporting
accepted/rejected, dangling links, duplicate ids, isolated nodes — and
crucially **which keys got absorbed into `attributes`** — would let a C++
emitter author iterate without touching PureScript.

That last item matters more since the absorb rule landed. Absorbing unknown
keys prevents silent *loss*, but it introduces silent *typos*: `"wieght"`
now lands in `attributes` and the weight quietly defaults to `1.0`, where
previously it would also have been dropped quietly. Neither behaviour
errors, because a strict reading would break forward compatibility. Making
absorbed keys **visible in a checker** is the right mitigation, and it is
the reason to build the checker before anyone ships an emitter against
this format.

**2. The end-to-end worked example.** A minimal app going from a `.json`
file to a rendered force graph. Already on the checklist below as the
quickstart; still the biggest gap for *any* newcomer, not just this
producer, and the actual point of the exercise — "the crucial first
visualisation without ceremony".

## JGF spec check — two divergences, both handled

Checked against the actual specification rather than recollection. Most
assumptions held; two did not.

**Per-item custom data is `metadata` in JGF, `attributes` here.** A
spec-shaped document's node and edge payloads would have landed as
`attributes.metadata` — lossless but nested a level too deep. Now aliased
in `normaliseStructure`, so a spec-shaped JGF document ingests with *zero*
unrecognised keys. If an item declares both, `metadata` is left alone and
surfaces in the diagnostics report, which is right for a genuinely
ambiguous document. Graph-level `metadata` already meant the same thing in
both formats.

**JGF also has a multi-graph form**, `{ "graphs": [ ... ] }`, which we do
not model. Previously this produced a baffling "At object key nodes: No
value was found". Now it produces a plain statement of what happened and
what to do about it. Silently taking the first graph was the tempting
option and would have surfaced as inexplicable data loss much later.

Per the producer's answer, we still borrow field names without chasing
conformance — no validator compliance, no per-edge `directed` override
(it absorbs into `attributes` and is not honoured).

## The worked example earned its place before it was even finished

Building `examples/force-graph/` immediately exposed a defect that all 11
passing tests had missed: **`toSim` targeted the wrong node type.**

`Hylograph.ForceEngine` has two different node types in the same package:

| Type | Module | Shape |
|------|--------|-------|
| `SimNode extra` | `.Types` | `{ x, y, vx, vy, index :: Int \| extra }` — the direct force-function path |
| `SimulationNode r` | `.Simulation` | `{ id :: Int, x, y, vx, vy, fx, fy \| r }` — what `Sim.setNodes` accepts |

`toSim` produced the first. The managed simulation — which is what every
actual consumer uses, including `site-explorer` — consumes the second. And
because I had put `id :: String` in the extra row, it collided head-on with
`SimulationNode`'s required `id :: Int`: the output could not have been fed
to `Sim.setNodes` at all, not even by adding fields.

The tests did not catch this because they only ever asserted properties of
`toSim`'s output. Nothing type-checked that output against the API it
exists to feed. The example does, by construction — that is the argument
for having one, and for building it *before* publishing rather than after.

Fixed: `DefaultNode = SimulationNode ( key :: String, label :: String )`.
The simulation's integer `id` is the array index; the wire format's string
id lives in `key`. Tests now assert both, and the example renders.

Verified in a browser, not merely compiled: the graph draws, the isolated
node is visibly detached, and a link to an undeclared node logs
"1 link(s) reference nodes that were never declared" instead of vanishing.

## Two ecosystem findings — written up separately

Both were found here but are ecosystem-level, so they live in
`kb/research/hylograph-public-api-leaks.md`:

1. **`ForceEngine.Types`' `SimNode`/`SimLink`/`RawLink`/`SimulationState`
   are dead code** — zero importers anywhere, duplicates of the
   `hylograph-d3-kernel` types, and the direct cause of the `toSim` defect
   above. Safe to delete.
2. **`Hylograph.Internal.*` is the de-facto public API** — ~470 import
   statements reach into it from outside `hylograph-selection`, 175 of them
   for `ElementType` alone.

## An API defect in hylograph-selection, found in passing — FIXED

`ElementType` — needed for every single `elem` call, and therefore by every
consumer of HATS — was only reachable via
`import Hylograph.Internal.Element.Types (ElementType(..))`, because
`Hylograph.HATS` did not re-export it.

That was an fp-police D1 violation (`.Internal.` import in application
code) forced on users *by the public API*, and `site-explorer` had exactly
the same import for exactly the same reason. It undercut the zero-ceremony
goal directly: a newcomer following the docs was made to reach inside a
library on their first visualization.

**Fixed in `hylograph-selection` 0.5.2**, published 2026-07-28. The
investigation grew well beyond this one type — ~470 imports across the
ecosystem, and a root cause that was not what it looked like — so it is
written up in full at `research/hylograph-public-api-leaks.md`.

The short version: those modules' headers had been telling readers to
"use the public API in `Hylograph.Behavior`" for years, and
`Hylograph.Behavior` was never written. Not a boundary being ignored — an
unfinished one.

One consequence lands back here, and is the reason this section says fixed
while the example still carries the offending import: see *Dependency
updates* below. Publishing a version does not make it reachable.

## Reconciliation with ShapedSteer `DAG.JSON` — resolved

**No format collision. This is the first graph *interchange* format, not the
second.** `DAG.JSON` is ShapedSteer's application-state serializer: nodes
carry `content` (Code/Markdown/Data/Task/Build), `value` (a `CellValue`
with computation states — Ready/Stale/Computing/Failed/Pending/Empty),
`executor` (Human/AIAgent/Compute) and `meta`. It serialises a live
workbench document including evaluation state. The overlap with an
interchange format is only the topological skeleton.

Checked empirically rather than by reading: a ShapedSteer-shaped document
fed to `decodeGraph` was **accepted, and everything but the skeleton was
silently discarded** — `content`, `value`, `executor`, `meta.label`,
`meta.tags`, and edge `kind` all gone, re-encoding to bare `{id}` nodes.
That was a hole in our format, not in ShapedSteer's, and it is now fixed
(see below). The same document now ingests losslessly.

Two follow-ups for the anti-synergy survey, not blockers here:

- `DAG.JSON` is ~400 lines of hand-written encode/decode *pairs* — exactly
  what entries 125 and 127 argue against, with the predicted consequence
  that the two directions must be kept in agreement by hand. It also
  reimplements `Data.Traversable.traverse` (with `Array.snoc` in a loop,
  so O(n²)) and `Data.Either.note` at the bottom of the file.
- Its decoders fall back silently (`decodeCellValueOr`, `decodeNodeMetaOr`,
  `decodeExecutorMaybe`) rather than failing, so a malformed document
  produces a plausible-looking DAG. Worth revisiting when ShapedSteer next
  gets attention.

Neither needs doing to publish this package. If ShapedSteer ever wants to
emit interchangeable graphs, it can express topology via `graphCodec` and
carry its payload in `attributes` — which now works without loss.

## FP / idiom audit

Ran `/fp-police` over the package plus a manual review. Mechanical
categories came back clean: no `unsafeCoerce`, `unsafePerformEffect`,
`unsafePartial`, `unsafeCrashWith`, `Effect.Ref`, `fromJust`,
`unsafeIndex`, no FFI, no `.Internal.` imports, no compat shims, no missing
type signatures, no warnings in our own source.

Three real findings, all fixed:

1. **`assertTrue'` was hand-rolled in the test module** — with the identical
   name and signature to `Test.Assert.assertTrue'`, which was already
   imported from the same module. Reimplementing a standard-library
   function is the precise sin flagged in `DAG.JSON` two paragraphs above,
   committed in this package on the same day. Deleted; using the library's.
2. **`if g.links == [] then ...`** — structural array equality where
   `Array.null` is the idiomatic and cheaper test.
3. **A local `maybe` shadowing `Data.Maybe.maybe`** in a test `where`
   clause. Removed in favour of the import.

Two design points examined and deliberately kept:

- **`Either String` at the entry points** trips fp-police's "string errors
  instead of ADTs" rule. Kept, because no structure is actually lost:
  `decodeGraph` is exactly `CA.decode graphCodec <<< normaliseJson` with
  the error rendered, and both halves are exported, so the structured
  `JsonDecodeError` path is a composition away. This is now documented
  rather than implicit — the alternative, adding a second decode function
  differing only in error type, would be redundant API surface.
- **Type aliases rather than newtypes** for `GraphJSON` / `NodeJSON` /
  `LinkJSON`, and raw `String` for wire-level node ids. House style prefers
  newtypes for domain concepts, but these are boundary DTOs mirroring JSON;
  entry 126's "decode at the boundary, work with types internally" puts the
  newtypes on the *inside* (`NodeId`, `Graph`, `DAG` in `hylograph-graph`),
  which is where they are. Newtyping the wire records would fight the
  zero-ceremony goal for no invariant gained.

The one wart flagged in the first pass — `resolveLinks` taking a bare
`Array String` that nothing stops you filling with labels — has since been
fixed by typing it as `Array NodeId`, reusing `hylograph-graph`'s existing
newtype rather than minting a second one. Newtypes are erased at runtime,
so this costs a `map NodeId` at the call site and nothing else. Worth doing
now specifically because the only call sites were internal: after
publishing, the signature is frozen.

## Dependency updates — 2026-07-28

`hylograph-selection` 0.5.2 and `hylograph-simulation` 0.6.0 both landed
(see `research/hylograph-public-api-leaks.md`). Two consequences here:

**The `SimNode` trap is gone.** `hylograph-simulation` 0.6.0 deletes the
dead `SimNode`/`SimLink`/`RawLink`/`SimulationState` types that this
package's `toSim` was mistakenly written against. The warning comment in
`Sim.purs` was rewritten as a *historical* note rather than deleted — the
part worth keeping is how the mistake survived a full test suite.

**The example still imports `Internal`, and cannot stop yet.** 0.5.2
re-exports `ElementType` from `Hylograph.HATS` precisely so the example
would not have to. But package sets pin versions and override dependency
ranges, and no published set yet carries 0.5.2 — the newest, 80.0.0,
predates it. So the example resolves 0.5.1 and the re-export is not there.
An `extraPackages` override would force it and was deliberately not used;
the import now carries a comment saying what blocks it and when to remove
it.

Worth generalising, because it caught us out: **publishing a version does
not make it reachable.** Widening dependency ranges is necessary but not
sufficient; the package set is the actual gate.

## Findings surfaced during implementation

Three things the implementation turned up that the design note could not
have known, recorded here because two of them are ecosystem-level:

**`Data.Graph.Weighted` cannot represent an isolated node.** It builds its
node set from edges, and the public API as of `hylograph-graph` 0.3.0
exports no `addNode`. So `toWeightedDigraph` and `toDAG` drop nodes with no
incident links, while `toGraph` (which takes the node set explicitly) does
not. The test suite asserts the current behaviour rather than papering over
it, so adding `addNode` upstream will surface as a failing test. This is a
genuine gap in `hylograph-graph`, not a quirk of the adapter.

**A record codec silently ignores unknown fields.** This is standard
codec-argonaut behaviour and entirely reasonable in general, but for an
*ingestion contract* it is quiet data loss: `{ "id": "a", "group": 1 }` —
the most common node shape in the wild — decoded to a node with no `group`
and no complaint. `normaliseJson` now folds unrecognised per-item keys into
that item's `attributes` before decoding, so foreign fields land where the
format says such fields live. Found by testing against a real foreign
document rather than by reading the code.

**`Data.Codec.Argonaut.Common.foreignObject` is a trap.** Despite the name
it encodes an `Object` as an array of two-element key/value arrays, not as
a JSON object — it is the function you would reach for by name and it would
have produced output no external producer could recognise. `CA.jobject` is
the correct primitive. There is a regression test guarding this specifically.

**`phyllotaxis` already existed.** Initial node positions cannot be omitted
(`SimNode` is a closed record) and seeding every node at the origin makes
the first simulation tick degenerate, so `toSim` needed a spiral layout —
which `DataViz.Layout.Pattern.phyllotaxis` in `hylograph-layout` already
provided. This is exactly the anti-synergy the deferred survey is meant to
catch, found by luck rather than by process. It cost one grep to avoid and
would have been invisible in review.
