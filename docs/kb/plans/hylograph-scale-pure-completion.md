# Hylograph Scale.Pure — Completion Plan

**Status**: In progress
**Date**: 2026-03-30
**Context**: Scale.Pure exists with core operations working. D3 golden tests translated. A few edge cases remain.

## Current State

- `Hylograph.Scale.Pure` — 521 lines, passes original test suite
- `Hylograph.Scale.D3` — renamed copy of old D3-backed implementation
- `Hylograph.Scale.ColorSchemes` — all categorical palettes as pure arrays
- Golden tests: LinearGolden (18), PowGolden (19), LogGolden (14) — ~155 assertions from D3's test suite
- Published: selection@0.4.0, simulation@0.4.0, simulation-halogen@0.4.0, music@0.3.0

## Remaining Tasks

### 1. Fix tickSpec algorithm (HIGH PRIORITY)

Current `tickIncrement` doesn't match D3's `tickSpec` exactly. Key differences:
- D3 uses `Math.round` for tick boundary calculation, we use `ceil`/`floor`
- D3 has recursive fallback: `if (i2 < i1 && 0.5 <= count && count < 2) return tickSpec(start, stop, count * 2)`
- Sub-1 step encoding needs exact match for nice to work on domains like `[0, 0.96]`

**Reference**: https://github.com/d3/d3-array/blob/main/src/ticks.js
**Test**: `[0, 0.96] # nice` should produce domain `[0, 1]`

### 2. Fix clamped invert

D3 clamps inverted values to the domain when `clamp(true)` is set. Our `buildInverse` doesn't apply clamping.

**Fix**: In `buildInverse`, when `clamped` is true, clamp the result to domain bounds.

### 3. Port Scale.FP to use Scale.Pure

`Hylograph.Scale.FP` provides higher-level combinators (sample, sampleRange, tickPositions, normalize, etc.). Currently imports from `Hylograph.Scale` (D3). Create `Hylograph.Scale.Pure.FP` or update FP to use Pure.

Functions to port: `sample`, `sampleRange`, `tickPositions`, `niceModifier`, `clampModifier`, `combineModifiers`, `normalize`, `scaleExtent`, `scaleMidpoint`, `scaleInRange`

### 4. Vendor sequential/diverging color interpolators

The sequential interpolators (Viridis, Blues, Plasma, etc.) are functions `[0,1] → color string`. D3 implements them as 256-entry lookup tables with linear interpolation.

Options:
- Embed the lookup tables as PureScript arrays (most accurate, ~2KB per scheme)
- Implement the mathematical color space formulas (Cubehelix for Viridis, etc.)
- Vendor just the most-used ones (Viridis, Blues, RdYlGn) and add others on demand

### 5. Vendor RGB/HSL interpolation

`interpolateRgb` and `interpolateHsl` — straightforward color math:
- Parse hex/rgb colors to components
- Lerp in the target color space
- Convert back to CSS color string

### 6. Update Hylograph.Scale to re-export from Scale.Pure

Once all tests pass:
- `Hylograph.Scale` re-exports everything from `Hylograph.Scale.Pure`
- `Hylograph.Scale.FP` re-exports from `Hylograph.Scale.Pure.FP` (or updated inline)
- Delete `Scale.js`, `Scale/FP.js`
- Remove `d3-scale`, `d3-scale-chromatic`, `d3-interpolate` from package.json

### 7. Publish selection@0.5.0

Final version with zero D3 dependencies in the selection package.

## Test Strategy

- Run D3 golden tests against Scale.Pure after each fix
- Compare outputs of Scale.D3 vs Scale.Pure for any differences
- The tests are the safety net — when all ~155 golden assertions pass, we're done

## Files

| File | Purpose |
|------|---------|
| `src/Hylograph/Scale/Pure.purs` | Pure implementation (in progress) |
| `src/Hylograph/Scale/D3.purs` | D3-backed reference (for comparison) |
| `src/Hylograph/Scale/ColorSchemes.purs` | Categorical palettes (done) |
| `test/Test/Scale/LinearGolden.purs` | 18 tests from D3 linear-test.js |
| `test/Test/Scale/PowGolden.purs` | 19 tests from D3 pow-test.js + sqrt |
| `test/Test/Scale/LogGolden.purs` | 14 tests from D3 log-test.js |
