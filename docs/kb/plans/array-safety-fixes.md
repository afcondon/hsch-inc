# Array Safety Fixes for psd3-simulation and psd3-selection

**Status**: Plan
**Created**: 2026-01-25
**Category**: plan
**Tags**: safety, bugs, psd3-simulation, psd3-selection

---

## Situation

Two independent classes of `unsafeCrashWith` bugs were discovered causing intermittent crashes in applications using psd3-simulation and psd3-selection.

### Bug 1: Links.purs - Array Position vs Semantic Index

**Location**: `PSD3.ForceEngine.Links.swizzleLinks` (line 117)

**Symptom**: `unsafeCrashWith "swizzleLinks: Array index out of bounds: 5"` when nodes array has fewer elements.

**Root Cause**: `swizzleLinks` assumes link.source and link.target are valid array positions. But these are *semantic* indices (the node.index field value), not array positions. When the nodes array is filtered (subset), array positions no longer match node.index values.

```purescript
-- Bug: uses array position
unsafeArrayIndex nodes link.source  -- Crashes if link.source >= nodes.length

-- Safe alternative exists:
swizzleLinksByIndex _.index nodes links transform  -- Uses Map lookup by node.index
```

**Test Created**: `test/Test/ForceEngine/LinksSpec.purs` - 11 test cases including demonstration of the bug and verification that `swizzleLinksByIndex` handles it safely.

### Bug 2: Operations.purs - Decoupled Elements/Data Arrays

**Location**: `PSD3.Internal.Selection.Operations` - multiple locations where `BoundSelection` is constructed (lines 2990-2995, 3102-3107, and similar patterns).

**Symptom**: `unsafeCrashWith "renderTemplatesForBoundSelectionKeyed: index out of bounds"` during data join updates.

**Root Cause**: BoundSelection is constructed by concatenating elements from one source and data from another:

```purescript
let enterElements = map fst enterElementsAndMaps  -- From ACTUAL renders
let allElements = enterElements <> updateElements

let allData = unsafePartial case enterImpl of     -- From ORIGINAL selection
      PendingSelection rec -> rec.pendingData

let boundSel = Selection $ BoundSelection
      { elements: allElements              -- Actual rendered count
      , data: allData <> updateData        -- Original expected count (can differ!)
```

If rendering fails for any datum (DOM issues, exceptions), `enterElements.length < allData.length`, causing downstream crashes when iterating over data and indexing into elements.

**Key Insight**: Empty selections are legitimate (any of enter/update/exit can be empty in GUP). The invariant is: within a BoundSelection, `elements.length == data.length`.

---

## Target

### For Links.purs
1. `swizzleLinks` either:
   - Deprecated in favor of `swizzleLinksByIndex`, OR
   - Reimplemented to use Map lookup internally (matching `swizzleLinksByIndex` behavior)
2. All tests pass including the currently-disabled crash test (which should become a safe-behavior test)

### For Operations.purs
1. BoundSelection elements and data stay paired throughout the render flow
2. Invariant check on BoundSelection construction catches any violations immediately with clear error message
3. No more "index out of bounds" crashes from mismatched array lengths

### General
1. All existing tests continue to pass
2. New tests verify the fixed behavior
3. No breaking API changes (fixes are internal)

---

## Proposal

### Fix 1: Links.purs (Self-contained, do first)

**Option A - Deprecate and redirect** (recommended):
```purescript
-- | DEPRECATED: Use swizzleLinksByIndex instead.
-- | This function crashes when nodes is a filtered subset.
swizzleLinks :: forall node link result
   . Array node
  -> Array link
  -> (node -> node -> Int -> link -> result)
  -> Array result
swizzleLinks nodes links transform =
  -- Delegate to safe implementation using array index as key
  swizzleLinksByIndex (\_ -> ???) nodes links transform
  -- Problem: we don't have access to node.index field generically
```

**Option B - Add Ord constraint and use Map** (breaking change):
```purescript
swizzleLinks :: forall node link result
   . Ord node  -- NEW: requires Ord
  => Array node
  -> ...
```

**Option C - Keep unsafe but document clearly** (minimal change):
```purescript
-- | UNSAFE: Assumes link.source and link.target are valid array indices.
-- | Use swizzleLinksByIndex for filtered node subsets.
swizzleLinks :: ...
```

**Recommendation**: Option C for now (document the limitation), with a note that `swizzleLinksByIndex` is the safe alternative. The "forked" version already exists and works correctly.

### Fix 2: Operations.purs (More invasive)

**Step 2a - Keep elements/data paired during construction**:

Modify `renderTemplatesForPendingSelectionKeyed` to return the datum alongside each element:

```purescript
-- Current: returns Array (Tuple Element ChildMap)
-- Proposed: returns Array { element :: Element, datum :: datum, childMap :: ChildMap }
```

Then when constructing the final BoundSelection:
```purescript
let enterWithData = ...  -- Has element AND datum paired
let allElements = map _.element enterWithData
let allData = map _.datum enterWithData  -- Guaranteed same length!
```

**Step 2b - Add BoundSelection invariant check**:

Create a smart constructor:
```purescript
mkBoundSelection
  :: Array Element
  -> Array datum
  -> Maybe (Array Int)
  -> Document
  -> Selection SBoundOwns Element datum
mkBoundSelection elements dataArray indices doc =
  if Array.length elements /= Array.length dataArray
  then unsafeCrashWith $
    "BoundSelection invariant violated: "
    <> show (Array.length elements) <> " elements vs "
    <> show (Array.length dataArray) <> " data items"
  else Selection $ BoundSelection
    { elements, data: dataArray, indices, document: doc }
```

Replace all `Selection $ BoundSelection { ... }` with `mkBoundSelection ...`.

**Step 2c - Similar fix for ExitingSelection**:

Same pattern - elements and data must match in length.

### Fix 3: Additional unsafeCrashWith patterns (lower priority)

Several other `unsafeCrashWith` calls were found:
- Line 320-322: Contradictory `head`/`unsafeIndex` logic
- Lines 1896, 3128, 3149, 3184: Empty `parentElements` crashes

These are lower priority but should be reviewed for similar fixes (use NonEmptyArray at type level, or handle gracefully).

---

## Implementation Order

1. **Links.purs documentation fix** - Add clear documentation that `swizzleLinks` is unsafe with filtered nodes, recommend `swizzleLinksByIndex`

2. **Operations.purs Step 2b** - Add `mkBoundSelection` smart constructor with invariant check (fail fast with clear message)

3. **Operations.purs Step 2a** - Refactor render flow to keep elements/data paired (prevents the invariant violation)

4. **Update Links tests** - Change the disabled crash test to verify safe behavior once we decide on the fix approach

5. **Review remaining unsafeCrashWith patterns** - Lower priority cleanup

---

## Files to Modify

### psd3-simulation
- `src/PSD3/ForceEngine/Links.purs` - Add documentation/deprecation warnings
- `test/Test/ForceEngine/LinksSpec.purs` - Already created, may need updates

### psd3-selection
- `src/PSD3/Internal/Selection/Operations.purs` - Main fix location
  - Add `mkBoundSelection` smart constructor
  - Refactor BoundSelection construction sites (~10 locations)
  - Refactor render flow to pair elements with data

---

## Test Strategy

1. Existing `LinksSpec.purs` tests verify Links behavior
2. Add similar tests for Operations if feasible (may require DOM mocking)
3. Manual testing in ce2-website (the app experiencing intermittent crashes)
4. Verify all showcase apps still work after fixes

---

## Notes

- The `swizzleLinksByIndex` function already implements the safe pattern - it was created specifically to avoid the Ord constraint while handling filtered subsets correctly
- Empty selections are legitimate in GUP; the invariant is length matching, not non-emptiness
- The fixes are internal implementation changes; public API remains unchanged
