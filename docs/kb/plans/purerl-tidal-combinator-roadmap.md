---
title: purerl-tidal — combinator parity + compositional-vocabulary roadmap
category: plan
status: active
tags: [purerl-tidal, music, tidal, combinators, vocabulary]
created: 2026-05-02
summary: Plan for achieving parity with upstream Tidal's combinator surface in purerl-tidal, then extending it with new compositional vocabularies (tintinnabuli, Fugue-Machine-style fan-out, diatonic harmony, granular synthesis, tape-recorder semantics).
---

# purerl-tidal — combinator parity + compositional-vocabulary roadmap

## Overview

purerl-tidal has a solid F-algebra core (one event-stream carrier, multiple
per-target algebras — see `purerl-tidal-f-algebra` memory) and a working
binding/scheduler/MIDI dispatch chain, but the *expressive surface* — the
combinators a live coder reaches for — is roughly half of upstream Tidal.
This plan sequences the work to (a) reach upstream parity, then (b)
extend with vocabulary that makes sense for Andrew's modular + iPad +
DAW rig specifically.

## Two-layer caveat (applies to all batches below)

There are two surfaces in purerl-tidal:

1. **Tidal.Pattern.Core** — PureScript-level pattern algebra. Reachable
   from PureScript code.
2. **Tidal.Eval.Interpret** — the cell evaluator that the Calypso editor
   parses cells into. As of 2026-05-02 this only knows
   `fast`/`slow`/`fastCat`/`stack`. Even `rev` is unreachable from a
   live cell.

Combinators must be added to layer 1 first, then wired into layer 2.
The plan deliberately keeps these as separate steps — wiring half a
vocabulary into cells is worse than wiring all of it at once.

## Status

### Batch 1 — DONE 2026-05-02 (commit `48434f0`)

Eleven combinators added to `Tidal.Pattern.Core`:

**Trivials (one-liners on existing primitives):**

- `palindrome p = cat [p, rev p]`
- `superimpose f p = stack [p, f p]`
- `off t f p = stack [p, rotR t (f p)]`
- `inside n f p = fast n (f (slow n p))`
- `outside n f p = slow n (f (fast n p))`
- `range lo hi p = (\v -> v * (hi - lo) + lo) <$> p` (Pattern Number)
- `brak` — broken-beat: pad odd cycles with leading + trailing silence
- `loopFirst p` — replay cycle 0 forever

**Mechanicals (small new logic, no new primitives):**

- `stutter n t p` — stack of n copies of p, each shifted by `i*t`
- `ply n p` — repeat each event n times within its own time slot
- `chunk n f p` — divide cycle into n parts, apply f to a different part
  each cycle (rotates over n cycles)

20 new tests pass; suite now 253 / 0. Concrete-valued signatures
(Int/Rational/Time, not Pattern Int/Pattern Time) — purerl-tidal's
idiom diverges from upstream's patternify-everything convention.

### Batch 2 — NEXT (per-event RNG + degrade family)

One new primitive unlocks ~7 combinators:

**New primitive:**
- `randAt :: Time -> Number` — deterministic hash of event start time +
  cycle number to a `[0, 1)` float. Probably xorshift on a packed
  `(cycle, fractional-position)` key; matches upstream's approach.

**Combinators that fall out:**
- `degrade p` (default 50% drop), `degradeBy x p`, `undegradeBy x p`
- `sometimes f p` (50%), `sometimesBy x f p`, `often f p` (75%),
  `rarely f p` (25%)
- `shuffle n p` — random subdivision reorder

Tests: port from upstream `tidal-core/test/Sound/Tidal/UITest.hs`
where applicable.

### Design-deferred — needs conversation before code

- **`jux`** — Andrew leans toward `mult`-as-fan-out:
  `mult :: Array (Pattern a -> Pattern a) -> Pattern a -> Pattern a`
  with `jux f = mult [id, f]` as sugar. Both modular Y-cable and
  Aff-fork-join intuitions support this. See memory
  `project_purerl_tidal_jux_design.md`. Open question: how do branches
  route — sibling bindings? voice-pool slots? duplicate routing with
  per-branch transforms only?
- **`striate`** — only meaningful for sampler bindings (Rample, Arbhar
  in playback). Decision needed: scope to a sampler-binding subtype,
  or no-op for non-samplers, or refuse at parse time?
- **`fix`/`unfix`** — upstream uses string-keyed ControlPattern values
  for the predicate. Andrew's bindings are typed; needs a re-design
  against the binding registry. Mechanism is small once predicate
  language is decided.
- **`hurry`** = `fast r (speed r p)` — depends on `speed` semantics
  that are meaningful for samplers but not pitched modular voices.
  Couples to the binding-fork conversation around `jux`.

### Cell-evaluator wiring (Layer 2) — pending

Once batch 2 lands and the design-deferred decisions are made, wire the
expanded surface into `Tidal.Eval.Interpret` so cells can call them.
This is a separate, mechanical step — for each layer-1 combinator, add
a parser case + an interpret arm.

## Beyond parity — compositional vocabularies

Five extension ideas Andrew raised at the end of the 2026-05-02 session,
to be discussed properly the next session. Listed here as project seeds
so they survive context compression.

### 1. Tintinnabuli (Arvo Pärt)

Two-voice rule: M-voice plays a melody in a scale; T-voice plays only
notes from a tonic triad, choosing the closest triad note (above,
below, or alternating) to each M-voice note. Maps to a deterministic
function `tintin :: TintinMode -> Triad -> Pattern Note -> Pattern Note`
that walks events and emits T-voice. Composes well with `mult` (you'd
typically `mult [id, tintin Above triad] melody`).

**Effort:** half a day once `Triad` type and scale machinery exist.
Doesn't need RNG. Doesn't need new primitives — just the substrate.

### 2. Fugue Machine (iPad app)

Four playheads on the same melody, each independently configurable for
speed, direction, octave, transposition. Plays them simultaneously.

This is *literally* `mult` with four entries — strong validation of the
mult-as-primitive direction. Andrew has the app and will spec it
concretely. Implementation is essentially `mult [head1, head2, head3,
head4] melody` where each head is a transform stack.

### 3. Counterpoint generation

Much harder. Requires:

- **Diatonic harmony substrate** (build first, useful on its own):
  `Key`, `Scale`, scale-degree-aware patterns, transposition by
  scale degree, voice-leading helpers.
- **Voice-leading rules**: passing/neighbor tones, dissonance treatment,
  parallel-fifths-and-octaves avoidance.

First-species counterpoint over a cantus firmus is achievable as a
constraint search. Free counterpoint or fugue is research-grade.
Phase: ship the diatonic substrate as a generally-useful layer (it
also enables tintinnabuli, Fugue Machine transposition, scale-aware
degrade, etc.), then layer counterpoint generation as a separate
project on top.

### 4. Granular vocabulary

For Clouds, Arbhar, Beads (Andrew owns all three) plus iPad granular
apps. Each device has its own parameter set but they share an abstract
space:

- Grain size, grain density
- Position / scrub / freeze
- Pitch jitter, pitch quantization
- Texture / randomness amount
- Buffer/sample selection

Design as a typed `GranularParams` record with per-target rendering —
same shape as `s` and `n` work today across samplers. Maps onto the
existing `#` parameter-join cleanly. Sits between "another binding"
and "new primitive class" — it's a vocabulary extension to the carrier,
not a structural change.

### 5. Lubadh / Morphagene / Magneto via CV (the most interesting one)

These are *stateful* devices: record-then-play lifecycle, splice
triggers, position scrubs. CV control of recording is a different shape
from CV control of pure playback (Rample, Plaits).

Doesn't fit pure pattern algebra — needs a new "tape recorder"
vocabulary on top of the carrier:

```
record (forCycles 4) sourceA
  then loop (fast 2 . rev)
  then splice [0.0, 0.25, 0.75]
```

Compiles down to gates/CVs at the right times via the binding layer.
Potentially the most musically powerful of the five because it lets
the rig *capture and recombine* what Andrew is playing in real time,
rather than just play patterns at the rig.

**Effort:** large. New temporal layer above the pattern carrier.
Needs design from scratch.

## Architectural compatibility

All five extension ideas are compatible with the F-algebra direction
(memory `project_purerl_tidal_f_algebra.md`):

- 1, 2, 4 are **carrier extensions** — new vocabulary on the existing
  event-stream carrier.
- 3 needs a **new substrate** (diatonic harmony) but no architectural
  rework.
- 5 needs a **new temporal layer** above the carrier (the tape-recorder
  state machine). Probably the only one that's an architectural shift.

No major reworks required. Carrier + per-target algebras + bindings
all carry over.

## Status / Next Steps

**Immediate (next session):**

1. Combinator batch 2 — RNG primitive + degrade family + sometimes
   family + shuffle.
2. Talk through the five extension ideas. Get Fugue Machine spec from
   Andrew. Decide which to start.

**Medium-term:**

3. Cell-evaluator layer-2 wiring once parity is close to done.
4. `jux`/`mult` design conversation, then implementation.
5. `striate` and `fix`/`unfix` design + implementation.
6. Diatonic harmony substrate (gating tintinnabuli + Fugue Machine
   transposition + counterpoint).

**Longer-term:**

7. Counterpoint generation over the harmony substrate.
8. Granular vocabulary across modular + iPad.
9. Tape-recorder vocabulary for Lubadh/Morphagene/Magneto.

Each of 6-9 is a project-sized chunk on its own.
