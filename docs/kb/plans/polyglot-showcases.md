---
title: "Polyglot site — showcase architecture"
category: plan
status: active
tags: [polyglot, showcases, backends, jurist, purepy, purerl, wasm, honesty-layer]
created: 2026-06-13
summary: The two-proof showcase structure for polyglot.purescri.pt and the per-backend exhibit mapping. Recovered from Marginalia #134 notes 303/289 and made durable here for the site build.
---

# Polyglot site — showcase architecture

Durable capture of the showcase plan for the new `site/polyglot/`. The
canonical brainstorm lived only in the project tracker (Marginalia **#134
note 303**, with the curatorial frame in note 289); this doc lifts it into the
repo so the site build doesn't depend on a tracker note. Supersedes the older,
pre-Jurist inventory in [`release-plan-2026.md`](release-plan-2026.md) §2.2.

## Thesis

> **PureScript as the honesty layer of state consistency across diverse
> runtimes — a strongly-typed modern-day Tcl.**

Polyglot is a **curator / magazine**, not an owner. Each exhibit lives in its
own project tree; the site *links* them (Marginalia `related` edges), it doesn't
parent them. "Ports = lineage, Backends = machinery, Polyglot = the magazine."

The site makes **two proofs**.

---

## Proof 1 — Per-runtime showcases

*Clean functional programming on the runtime of your choice — one app each.*
A gallery; each card is one backend's flagship exhibit.

| Backend | Exhibit | What it proves | Live? | Status |
|---|---|---|---|---|
| **Python** (purepy) | **Embedding Explorer** — umap-learn, 140 points, typed Flask routes | PS compiles to Python; reach the ML/data stack with types intact | live (local: `/ee/`, port 8081) | **done** — rebuilt + verified 2026-06-11 |
| **Python** (purepy) | **Grid Explorer** — pandapower AC power flow on IEEE case14, N-1 contingency, cascading-failure, resilience metrics | the "electrical grid / power-line faults" demo; typed Flask over a heavy scientific lib | live (local: `/ge/`, port 8082) | **done** — rebuilt 2026-06-11 (`hypo-punter/ge-server`) |
| **Julia** (Jurist) | **Stability Atlas** — basins-of-attraction heat-map sweep + click-to-stream orrery, computed PS-on-Julia, streamed over a typed WebSocket | distributed PS-on-Julia *compute* as the point; numerics behind a typed FFI seam | live demo (needs the Julia service hosted) | feature-complete as a showcase (2026-06-13); **deployment deferred to this site work**. Basins-of-attraction is the standing north star. |
| **BEAM** (purerl) | **purerl-tidal** / **Atlantis** | OTP supervision + live-coded music on the BEAM | **video** (not live-in-browser) | Atlantis = #223; see Proof 2 |
| **Lua** (pslua) | **Scuppered Ligature** edge router (hypo-punter edge) | already PS→Lua in production; proves the Lua backend | infra (explanation, not a demo) | exists |
| **Go** (psgo) | — | single static binary, goroutines | — | likely **documented, not exhibited** (newest backend) |
| **Wasm GC** (katsujukou, #225) | **the site itself runs on Wasm** (dogfood) + adopt katsujukou's own benchmarks | the performance backend, proven by hosting the very page you're reading | the site | evaluate #225's existing demo/benchmarks *before* writing a new one. The "site-on-Wasm" dogfood is the chosen framing. |

Notes:
- **Stability Atlas can't be a static page** — the sweep and orrery are computed
  by the PS-on-Julia service and streamed; that distributed compute *is* the
  showcase. Browser-side already: axis schematic, small multiples, honesty
  meter. Hosting plan: TailScale Funnel → MacMini Docker, via `polyglot-deploy`.
  Pre-exposure fixes: ~35s Julia cold-start JIT (PackageCompiler.jl sysimage);
  per-visitor sweeps saturate Julia threads ~20s (fine for low traffic).
  See the `stability-atlas-*` memories.
- The Python pair is the strongest, already-working proof — lead with it.

---

## Proof 2 — The honesty layer

*Mixed runtimes, one type system.* The differential corpus made visible: the
same typed source on every backend, agreeing where the type system carried and
diverging only where documented. The landing's "run the same program
everywhere" strip is the seed of this.

**Atlantis** is the video poster child — the full browser + BEAM + Node
multi-runtime system, shown as a video rather than live-in-browser (its full
rig can't run in a visitor's tab).

### "Illegal states unrepresentable" — show, don't tell

Key reframe from note 303: **types shrink the SPACE, they don't guard the
CHANNEL.** (Whisper/CRUD-unison framings felt wrong because they're
error-*detection*; the real claim is that bad states are *unrepresentable*.)
Candidates:

- **A. The Silhouette** — render the state space as a shape; one identical
  silhouette per runtime column (the type *is* the silhouette). Untyped columns
  bloat differently per language. → the landing visual.
- **B. The Saboteur** — the player attacks the wires of a live **4-runtime ring**
  (rename a field, int-as-string, null, int32 overflow, surrogate truncation —
  the last two *are* our divergence ledger). In the typed ring, sabotage either
  fails to parse loudly and *identically* at the next boundary, or was a legal
  edit all along ("you cannot corrupt it, only edit it"). In the untyped twin,
  symptoms surface hops later. **Score = blast radius** — fun in untyped mode,
  a constant 1 when typed: *a game that is only fun without types.* → the core.
- **C. Greyed-Out Move** — pipeline assembly where illegal compositions are
  simply absent from the palette (phantom / session types); a JSON-mode toggle
  detonates downstream.

**Synthesis**: Saboteur core + Silhouette landing visual + an
*interpretation-identity slot machine* (player-chosen fuzz seed, 10k values
round-trip every codec, divergences: 0) — which would **build Jurist ADR-0008
(same-seed differential fuzzing) as a side effect.**

Honesty frame throughout: **parse-don't-validate at boundaries, total interior**
— the provable claim is *blast radius 1, always*.

Open question: the domain on the ring (abstract tokens / a tiny CRUD doc / a
four-referees game world). Earlier-but-still-live candidate: the **verb fan-out
app** — the browser builds a typed description, Python answers the calculus,
Julia answers the proofs, Hylograph renders the `Answer` values.

---

## Build order for the site

1. **Now**: a static Proof-1 gallery (cards → live/video/explained exhibits) +
   reframe the existing strip as the Proof-2 seed. Python pair links to live
   demos; Stability Atlas + Atlantis as "coming / video" until hosted.
2. **Next**: host the Stability Atlas Julia service (sysimage first); embed the
   Atlantis video; evaluate katsujukou's Wasm demo and decide the site-on-Wasm
   dogfood path.
3. **Later**: build one Proof-2 interactive (Saboteur seed first per note 303).

## Source pointers

- Marginalia **#134** (Polyglot, slug `lima-yankee-bravo-mike`) notes **303**, **289**, 267.
- `docs/backends/backend-comparison.md` — the family + divergence ledger.
- Stability Atlas: `purescript-backends/purescript-julia/examples/stability-atlas/` (Marginalia #219).
- Python demos: `purescript-backends/purescript-python-new/examples/{embedding-explorer,grid-explorer}/`.
