# Porting purescm (Chez) to Racket — Report Digest

**Status**: archival-reference
**Category**: research
**Created**: 2026-06-13
**Author**: Claude (digest of `RACKET_PORT_REPORT.md`, ~3,575 lines, decisions stamped 2026-02-22)
**Source**: `~/Downloads/RACKET_PORT_REPORT.md` (original, not in tree)

## Why this note exists

The source is a 3,575-line feasibility-and-implementation report for porting
**purescm** (PureScript → Chez Scheme backend) to **Racket** as a big-bang
rewrite emitting native `#lang racket/base`. It is mostly superseded but
contains a handful of findings worth keeping without re-reading the whole
thing. This digest captures the durable parts and flags the attribution trap.

## Provenance / the naming trap (read this first)

The report names its target **`purekt`** (the dir was `purkt`). **This is NOT
Fabrizio Ferrai's Purkt.** They collide on name only:

- **This report** = a *mechanical port of purescm → Racket*. purescm is
  credited to Nathan Faubion / Arista (see
  [`purescript-alternative-backends-comparison.md`](purescript-alternative-backends-comparison.md)).
  Reads as Claude-authored. No self-hosting ambition.
- **Fabrizio's Purkt** = a *separate* Racket backend that scope-expanded to
  self-hosting + ~10 libraries-to-publish (per
  [`../../backends/backend-comparison.md`](../../backends/backend-comparison.md),
  §"Racket — Purkt"). Its design doc is **not** in this tree — source from
  Fabrizio directly.

Before publishing the comparison site, do not conflate the two or credit this
report's design to Fabrizio. The standing "get attributions right" note in
`backend-comparison.md` applies precisely here.

**Dating**: decision blocks inside stamp **2026-02-22**, predating the Jurist
architecture (ADR-0001) and the from-scratch backend wave (e.g. the Python
backend at 422/426). A purescm→Racket mechanical port is a *third* lineage,
distinct from both Jurist-style emitters and Fabrizio's self-hosting Purkt.

## What the port would involve (shape)

Codegen translation is **highly mechanical**; the runtime library is the
labor. Pipeline is unchanged: CoreFn JSON → backend-optimizer → AST → text.

| Layer | Effort | Note |
|-------|--------|------|
| `Syntax`/`Printer`/`Convert`/`Constants.purs` | Rewrite, but mechanical | R6RS `library` → Racket `module`; `scm:` prefix vanishes (core forms are in `racket/base`); `define-record-type` → `struct` |
| `runtime.ss` → `.rkt` | Straightforward | Pure-Scheme logic ports directly |
| `pstring.ss` (1,433 lines) | The hard core | Rope-based UTF-16 strings + PCRE2 FFI |
| `finalizers.ss` | **Deleted** | Replaced by `ffi/unsafe/alloc` (see below) |
| 65 `.ss` FFI files in purescript-core | Wave-by-wave port | `.purs` untouched; `.rkt` added alongside `.js`/`.ss` |

## Durable technical findings (the reason to keep this)

**1. `ptr-ref _uint16` on a byte string compiles to the same Chez primitive.**
The feared hot-path regression (UTF-16 code-unit access) is a non-issue.
Reading Racket CS's `racket/src/cs/rumble/foreign.ss`, the author found
schemify inlines `(ptr-ref bv _uint16 n)` to `bytevector-u16-native-ref` —
exactly what purescm already uses — *when the first arg is a byte string*. So
`make-bytes` replaces Chez's `make-immobile-bytevector` with **zero hot-path
regression and no pinning**. Caveat: this is undocumented (the perf guide only
lists signed types), so it's load-bearing-but-fragile — pin a min Racket
version and add a regression benchmark. Useful intelligence for *any*
Racket-targeting PureScript or UTF-16-string work.

**2. Racket's exception model retires purescm's `raise-continuable` dance.**
purescm uses `raise-continuable` everywhere + a `call/cc`-escape at every
catch site. That's a defensive workaround for R6RS's "handler runs at the
raise point, and a non-continuable handler that *returns* double-faults"
semantics — dangerous across the C/PCRE2 FFI boundary. Racket's
`with-handlers` **unwinds the stack before running the handler**, so the
double-fault is structurally impossible. The whole pattern collapses to plain
`with-handlers`. (Never use Racket's low-level `call-with-exception-handler` —
it has the R6RS-style raise-point semantics.) This is also the clearest
explanation on record of *why purescm looks the way it does*.

**3. Several places Racket is simpler, not just equivalent:**
- **Finalization:** Chez guardians + `collect-request-handler` hook →
  `ffi/unsafe/alloc` `allocator`/`deallocator` wraps on the PCRE2 bindings.
  `finalizers.ss` deletes entirely; explicit free cancels the GC finalizer
  (no double-free).
- **Buffer copy:** per-code-unit Scheme loop → `bytes-copy!` (memcpy). The one
  place the Racket port is *definitively faster* than Chez.
- **Arrays:** drop SRFI 214 flexvectors → built-in `vector` for the pure
  `Array` (value-typed, never grown after construction); `data/gvector` only
  for mutable `STArray`.
- **Stack traces:** first-class via `exn-continuation-marks` +
  `continuation-mark-set->context`.

**4. C dependencies: two → one → (goal) zero.**
- **ICU dropped** — `string-upcase`/`downcase` use the same Unicode data;
  ~one extra alloc per case-conversion (not a hot path). Removes
  `libicuuc`, versioned symbol lookup, a Nix input, and DYLD path entries.
- **PCRE2 kept** for Phase 1; long-term goal is porting V8's irregexp to
  remove it. Motive: **`raco distribute` does not bundle C FFI deps** (open
  bug racket#3306 — `define-runtime-path` `.so`s land off the search path),
  forcing manual `.so`/`.dylib` copy + rpath fixup (`patchelf` /
  `install_name_tool`), and Racket **cannot** produce a single static binary
  (`ffi-lib` uses `dlopen`). macOS SIP still strips `DYLD_LIBRARY_PATH` from
  the Node-spawned `racket` subprocess in dev, so the `CHEZ_DYLD_LIBRARY_PATH`
  hack carries forward (renamed). Zero-C-deps is the real distribution prize.

**5. GC/FFI immobility analysis.** All PCRE2 calls are non-blocking and don't
retain pointers (PCRE2 copies the pattern at compile time), so plain
`make-bytes` buffers are safe passed directly as `cpointer?` — no
`'atomic-interior`, no `object->reference-address` equivalent. `ptr-add`
keeps the base reachable for offset slices. `'atomic-interior` would only be
needed for blocking calls, callbacks, or cross-call pointer stability (and
`#:in-original-place? #t` if ever called from a Racket place).

## The most reusable artifact: the cross-backend test harness

Independently of this specific port, the report's **differential testing**
design is worth lifting:

- Run the same 18 purescript-core suites on **JS × Chez × Racket**, compare
  stdout + stderr + exit code. Strict match for 16; relaxed (exit code +
  deterministic log lines only) for the 2 QuickCheck-seeded non-deterministic
  suites (`quickcheck`, `foreign-object`).
- Backend selection is a one-line `workspace.backend` swap; FFI files
  (`.js`/`.ss`/`.rkt`) coexist per package, picked up by extension.
- A parallel **JSONL benchmarking polyrepo** (shared `bench` package +
  per-backend runner workspaces + `compare.js`) covers pure/array/string/
  record/effect suites; ratios vs JS are the headline metric.

This is essentially the same idea as the Jurist "shared `Test.*` differential
corpus" (`backend-comparison.md`) — arrived at independently, and a good
template if the comparison site ever wants a live "same program, every
backend" strip.

## Bottom line

- **Superseded:** the `purekt` naming, and the go/no-go framing — the backend
  landscape moved to Jurist + from-scratch emitters.
- **Keep:** the `ptr-ref _uint16`/byte-string/schemify finding; the
  R6RS-vs-Racket exception-model explanation; the Racket FFI translation table
  + GC/immobility call-site analysis; the cross-backend test + benchmark
  harness design; and the attribution distinction (this report ≠ Fabrizio's
  Purkt).
