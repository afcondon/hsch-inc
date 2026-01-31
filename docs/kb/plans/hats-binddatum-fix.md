# HATS bindDatum Fix Plan

## Status: Implemented (2026-01-31)

**Commit:** `7e4c452` on `feature/hats-migration` in hylograph-selection

## Summary

The HATS implementation had a bug where datum was never bound to DOM elements, breaking behaviors that need to read datum at event time (e.g., simulation drag). The fix was small and architecturally clean.

## The Bug

**Symptom:** Drag behavior in ForcePlayground silently fails.

**Root cause:**
- `InterpreterTick.js` exports `bindDatum` which sets `element.__data__ = datum`
- `InterpreterTick.purs` never imports or calls it
- Drag handler reads `element.__data__.node` → gets `undefined` → logs warning and exits

**Affected behaviors:**
- `simulationDrag` / `simulationDragNested` - drag for force simulations
- Any behavior that retrieves datum from DOM element at event time
- Any external code expecting D3-style `__data__` on elements

**Unaffected:**
- Static attributes (closure-captured values)
- Thunked behaviors where handler captures all needed data
- Coordinated highlighting (uses thunked identify functions)

## The Fix

Add `bindDatum` call in the DOM interpreter when rendering fold items.

### Location

`src/Hylograph/HATS/InterpreterTick.purs` in `renderEnteringItem`:

```purescript
renderEnteringItem p foldName keyFn template gupSpec idx datum = do
  let itemTree = template datum
  let key = keyFn datum
  case itemTree of
    Elem spec -> do
      el <- createElementWithNS spec.elemType doc
      appendTo p el
      setKey el key
      setFoldName el foldName
      bindDatum el datum  -- ADD THIS LINE
      applyAttrs el spec.attrs
      ...
```

Also need to bind datum on UPDATE path (existing elements getting new data).

### FFI Addition

Add foreign import in InterpreterTick.purs:
```purescript
foreign import bindDatum :: forall a. Element -> a -> Effect Unit
```

The FFI already exists in InterpreterTick.js (line 41-43).

## Why This Is Architecturally Clean

HATS Tree is a **pure specification**. Different interpreters handle it differently:

| Interpreter | Output | Needs `__data__`? |
|-------------|--------|-------------------|
| English | String description | No |
| Mermaid | Diagram markup | No |
| MetaAST | AST visualization | No |
| **DOM (InterpreterTick)** | **Real DOM + events** | **Yes** |

`bindDatum` is an **implementation detail of the DOM interpreter**, not a leak in the HATS abstraction. The Tree spec doesn't know about `__data__` - that's just how DOM event handlers access their datum.

## Naming Cleanup

While we're here, rename "D3 Interpreter" references to "DOM Interpreter":

- We've eliminated most D3 dependencies (d3-drag, d3-zoom)
- We're doing direct DOM manipulation, not wrapping D3 selections
- "D3" in the name is misleading

Files to check:
- `src/Hylograph/Interpreter/D3.purs` → consider rename
- Any documentation referencing "D3 interpreter"

## Options Considered

| Option | Description | Verdict |
|--------|-------------|---------|
| A: bindDatum in DOM interpreter | Small fix, architecturally clean | **Recommended** |
| B: Behaviors take datum explicitly | More code changes, unclear benefit | Not needed |
| C: Two-phase rendering | Over-engineering | Not needed |
| D: AST for simulation, HATS for static | Ecosystem fragmentation | Avoid if possible |
| E: Drop HATS entirely | Loses composition benefits | Last resort |

## Implementation Steps

1. Add `foreign import bindDatum` to InterpreterTick.purs
2. Call `bindDatum el datum` in `renderEnteringItem` (ENTER path)
3. Call `bindDatum el datum` in update handling (UPDATE path)
4. Test ForcePlayground drag behavior
5. Rename D3 interpreter references (optional, lower priority)

## Implementation Complete

All steps implemented:
1. ✅ Added `foreign import bindDatum` to InterpreterTick.purs
2. ✅ Call `bindDatum el datum` in `renderEnteringItem` (ENTER path)
3. ✅ Call `bindDatum el datum` in update handling (UPDATE path)
4. ✅ Test ForcePlayground drag behavior - **confirmed working**
5. ⏳ Rename D3 interpreter references (optional, lower priority)

## Related Documents

- `docs/kb/reference/git-state-audit-2026-01-31.md` - Current git state
- `src/Hylograph/HATS/InterpreterTick.purs` - Main file to modify
- `src/Hylograph/HATS/InterpreterTick.js` - FFI (bindDatum already exists)
