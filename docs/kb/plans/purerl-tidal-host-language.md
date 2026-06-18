---
title: purerl-tidal — host-language layer for cells (option 3)
category: plan
status: planned
tags: [purerl-tidal, calypso, cells, host-language, branched]
created: 2026-05-03
summary: Server-side expression layer that unlocks the Branched fork/merge vocabulary (jux, mult, gate, crossfade, alternate) from Calypso's code pane and cells. Both panes ship to the same WS endpoint, so one fix reaches both surfaces.
---

# purerl-tidal — host-language layer for cells

## Why

After landing the `Branched` v1 sketch on `fork-merge-design`, the
new vocabulary (`jux`, `mult`, `gate`, `crossfade`, `alternate`) is
reachable only from PureScript code. Calypso's code pane and cells
both ship cell-text to `ws://localhost:3012/ws`, parsed by
`Tidal.WebSocket.Handler.parseInputMessage` (PS) /
`Tidal.WebSocket.Handler.erl` (the live wire). Today that handler
accepts:

- Verb-prefixed: `gate <ch> <p>`, `cv <bus> <p>`, `bind <name> ...`,
  `load <set>`, `hush`, `slot ...`, `fh2-*`, `midi-device ...`,
  `log-level <n>`, plus a few more
- Pattern arg `<p>` is **always mini-notation** parsed via `safe_parse`
- Bare `<text>` falls back to legacy single-pattern + named-binding
  dispatch

There is **no host-language layer** anywhere in this chain. To reach
`jux`/`mult`/etc. from cells, the server's pattern parser needs to
accept expressions, not just mini-notation.

This plan is the "option 3" multi-session work referenced in the
2026-05-03 worklog.

## Architecture

Three new components, plus tests:

### 1. `src/Tidal/Expr.purs` — expression parser + evaluator

Small expression language with this AST:

```purescript
data Expr
  = EVar String           -- identifier reference (e.g. `rev`)
  | ENum Rational         -- number literal
  | EStr String            -- mini-notation string literal "bd sn"
  | EApp Expr (Array Expr)  -- function application
  | EList (Array Expr)     -- [e1, e2, e3]
  | ETag String Expr       -- name:expr (Voice tag in fan-out)
```

Tokens: identifiers (alphanumeric + `-`), numbers (Int / Rational
literals like `1/4`), strings (double-quoted mini-notation), brackets
`[ ]`, parens `( )`, commas, colons.

Evaluator dispatches on a registry of named combinators that map to
typed PureScript functions:

```purescript
parseExpr   :: String -> Either String Expr
evalExpr    :: Expr -> Either String (Pattern ValueMap)
eval        :: String -> Either String (Pattern ValueMap)
eval src    = parseExpr src >>= evalExpr
```

The registry — initial set:

| Name         | PureScript                                | Notes |
|--------------|-------------------------------------------|-------|
| `id`         | `identity`                                | transform |
| `rev`        | `Tidal.Pattern.Core.rev`                  | transform |
| `slow N`     | `Tidal.Pattern.Core.slow (fromInt N)`     | transform |
| `fast N`     | `Tidal.Pattern.Core.fast (fromInt N)`     | transform |
| `palindrome` | `Tidal.Pattern.Core.palindrome`           | transform |
| `every N f`  | `Tidal.Pattern.Core.every N (lookup f)`   | transform |
| `jux f p`    | `Tidal.Pattern.Branched.jux (lookup f) p` | combinator |
| `mult bs p`  | `Tidal.Pattern.Branched.mult bs p`        | combinator |
| `gate gm bs p` | wrap fan-out + branched gate            | combinator |
| `crossfade s bs p` | wrap fan-out + branched crossfade   | combinator |
| `alternate bs p` | wrap fan-out + branched alternate     | combinator |

Branched combinators take a fan-out spec (`[name:transform, ...]`) as a
list of `ETag` entries; the evaluator builds the `Branched` internally
from `voiced "name" transform` triples.

Mini-notation strings are parsed via `Tidal.Parse.Parser.parseTPat` and
lifted to `Pattern` via `Tidal.Eval.Interpret.tpatToPattern`.

### 2. New `Scheduler.Msg` variant

```purescript
| UpdateGateTrackP Int (Pattern ValueMap)
```

Accepts a pre-built `Pattern` (closure) instead of a mini-notation
string. The existing `UpdateGateTrack Int String` path stays unchanged
for plain mini-notation cells. `MIDIScheduler` adds an arm for the new
variant that goes straight to the schedule-events path, bypassing the
parse step.

### 3. New verb form in `Handler.erl`

Extend the existing `gate <ch> <p>` parser to recognise an expression
form when the pattern starts with `:`:

```
gate 1 c4 e4 g4 b4               -- existing: mini-notation literal
gate 1 :jux rev "c4 e4 g4 b4"    -- NEW: expression form
```

Wire flow:

1. Erlang `try_parse_prefixed` matches `gate <ch> :<rest>` and routes
   to a new branch
2. New branch calls into PureScript: `tidal_expr@ps:eval(Rest)`
3. PureScript returns `{ok, Pattern}` or `{err, Reason}`
4. On `ok`, send `{updateGateTrackP, Ch, Pattern}` to scheduler
5. On `err`, return `ERROR: expr: <reason>` to the caller

Other verbs (`cv`, `esx`, `bind`-bound voices like `lap "..."`) get the
same treatment in a follow-up once the `gate` path is proven.

### 4. `Test/ExprSpec.purs`

Round-trip tests for each combinator:

```
parse "jux rev \"c4 e4 g4 b4\""  →  parses cleanly
eval "jux rev \"c4 e4 g4 b4\""   →  Right pat
queryArc pat 0 1                  →  8 events (matching jux rev m4 from
                                     BranchedSpec)
```

Plus error cases: unknown name, malformed list, missing string arg.

## Cell-pane examples (the reachable end-state)

```
gate 1 :jux rev "c4 e4 g4 b4"

gate 1 :mult [L:id, R:rev, harm:slow 2] "c4 e4 g4 b4"

gate 1 :alternate [a:id, b:rev, c:fast 2] "bd sn hh cp"

gate 1 :crossfade "<lead pad lead bass>" [lead:id, pad:slow 2, bass:id] "c4 e4 g4 b4"

gate 1 :gate [pad:false, lead:true, bass:true] [lead:id, pad:slow 2, bass:id] "c4 e4 g4 b4"
```

(The last form's `[pad:false, ...]` is a `Map Voice (Pattern Boolean)`
where `false` / `true` are sugar for `pure false` / `pure true` —
extension to allow real Pattern Boolean literals like `"<t f t f>"` is
later work.)

## MVP limits (extensible later)

1. **No nesting on first pass.** `jux (slow 2 (...))` not supported.
   Each verb takes its leading args + a final pattern string. Adding
   parens + recursive parsing is a clean follow-up once the bones work.
2. **`f` in `jux f` must be a single registry name.** No partial
   application or lambdas. `slow 2` is a name, but `\p -> slow 2 (rev p)`
   isn't.
3. **Only `gate <ch>` gets `:<expr>` form first.** Other verbs (`cv`,
   `bind`-bound names) follow once `gate` is proven.
4. **Pattern type is `Pattern ValueMap`** to match what the scheduler
   currently consumes. The existing `tpatToPattern` produces this from
   mini-notation; expressions feed into the same pipeline.
5. **No partial Pattern Boolean literals in `gate` map.** Map values
   are `false`/`true` (pure constants) for v1; full Pattern Booleans
   come later.

## Build order

1. Sketch `Tidal.Expr` parser + evaluator with no Branched, just
   `slow`, `fast`, `rev`, `palindrome`, `every` over mini-notation
   strings. Verify in PureScript-only tests.
2. Add Branched combinators (`jux`, `mult`, `alternate`, `gate`,
   `crossfade`) to the registry. Verify in tests.
3. Wire the new `Scheduler.Msg` variant + `MIDIScheduler` arm.
4. Add the new `gate <ch> :<expr>` branch in `Handler.erl` calling
   into PS-compiled `tidal_expr@ps:eval`.
5. Smoke test end-to-end via Calypso → Laplace.
6. Add error-path tests; tighten error messages.

## After this lands

- Tour cells become directly typeable in Calypso, no `make tour`
  rebuild loop.
- Existing mini-notation cells continue to work unchanged (no `:`
  prefix).
- Path is open for nesting, partial application, lambdas, real
  Pattern Boolean literals — all incremental from this base.
- Branched-aware UI features (Sankey rendering of fan-out) get a
  reachable AST to introspect, since the parsed `Expr` can be sent
  back to the editor for visualization.

## Status

- Planned 2026-05-03 PM. Branch `fork-merge-design` has Branched v1
  in place. Compact then start build order step 1.
