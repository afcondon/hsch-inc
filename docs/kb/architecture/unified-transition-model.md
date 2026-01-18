# Unified Transition Model Design

**Status**: Draft / Brainstorming
**Created**: 2026-01-18
**Context**: D3 dependency reduction Phase 6 analysis

## Problem Statement

PSD3 currently has two incoherent animation mechanisms:

1. **d3-transition** (via FFI) - CSS-style attribute animations
2. **PSD3.Transition.Engine** (pure PS) - tick-driven interpolation

These don't compose well. D3 has the same problem: transitions and simulations are fundamentally at odds because both want to control element attributes (especially position).

### Current Usage

| Mechanism | Where Used | Controls |
|-----------|------------|----------|
| d3-transition | Tour demos, TreeAPI examples | opacity, radius, position (non-sim) |
| Simulation tick | Force layouts (Les Mis, EE, CE) | position (cx, cy) |
| Engine (new) | Not yet integrated | designed for simulation-aware |

### The Incoherence

- d3-transition: "Animate from A to B over duration, I control the element"
- Simulation: "Each tick I set position based on physics, I control the element"
- You can't have both controlling the same attribute simultaneously

## What Are D3 Transitions Actually?

**NOT CSS transitions.** They are:
- JavaScript-driven via `requestAnimationFrame`
- `d3-interpolate` for value tweening
- `d3-ease` for timing curves
- Imperatively update DOM attributes each frame

**CSS transitions** are different:
- Browser compositor handles them
- Declared via CSS (`transition: opacity 0.3s ease-out`)
- Hardware accelerated for transform/opacity
- Hands-off from JavaScript

## Key Insight: Attribute Ownership

Different mechanisms should own different attributes:

```
┌─────────────────────────────────────────────────────────────────┐
│                        ATTRIBUTE CONTROL                        │
├─────────────────────────────────────────────────────────────────┤
│  Attribute    │ Static  │ Transition  │ Simulation │ Combined  │
├───────────────┼─────────┼─────────────┼────────────┼───────────┤
│  cx, cy       │    ✓    │     ✓       │     ✓      │    ✗*     │
│  r (radius)   │    ✓    │     ✓       │     ✗      │    N/A    │
│  opacity      │    ✓    │     ✓       │     ✗      │    N/A    │
│  fill         │    ✓    │     ✓       │     ✗      │    N/A    │
└─────────────────────────────────────────────────────────────────┘
* Position can't be BOTH transitioned and simulated simultaneously
```

**But they CAN coexist temporally:**

```
ENTER:   [transition opacity 0→1] + [simulation takes over position]
UPDATE:  [simulation controls position] + [transition radius change]
EXIT:    [release from simulation] + [transition opacity 1→0, then remove]
```

## Open Questions

### 1. Staggering

**Question**: How do staggered animations work across all engines?

**Analysis**: Staggering makes sense for:
- Enter transitions (elements appear in sequence)
- Exit transitions (elements disappear in sequence)
- Non-simulated position transitions (wave effects)

Staggering does NOT make sense for simulation - physics doesn't stagger.

**Implication**: Staggering is a transition-engine concern, not a simulation concern. The unified model should keep staggering as a TransitionConfig feature.

### 2. Chaining

**Question**: How do we sequence "enter transition → simulation → exit transition"?

**Current approach**: Engine has explicit phases:
- `start` - begin transition from initial state
- `tick` - advance by delta
- `isComplete` - check if done

No chaining concept in simulation - it just runs continuously until stopped.

**Implication**: Chaining is about lifecycle phases (enter/update/exit), not about composing transitions. The AST's JoinBehavior already captures this:

```purescript
{ enter: Just { ... }   -- Phase 1: element appears
, update: Just { ... }  -- Phase 2: element exists
, exit: Just { ... }    -- Phase 3: element leaves
}
```

The interpreter sequences these. Chaining within a phase (e.g., "fade in THEN grow") would be a separate concern.

### 3. Interruption

**Question**: What happens if data changes mid-transition?

**Analysis**:
- CSS transitions: Browser handles gracefully (transitions to new value)
- D3 transitions: Interrupted transition is cancelled, new one starts
- Simulation: Data change = nodes added/removed, physics continues
- Element removed during transition: Undefined behavior, potential crash

**Implications**:
- Need explicit interruption semantics
- "Transition to current" pattern (start from wherever you are)
- Exit transitions should complete before removal (current d3 pattern)
- Consider: should we track "in transition" state?

### 4. WASM Coordination

**Question**: How does the Rust kernel report ticks back to PureScript?

**Current implementation**: Must be working somehow - need to investigate.

**Likely mechanisms**:
- Callback passed to WASM at init
- WASM calls JS function on each tick
- JS function updates PS state / triggers render

**TODO**: Document actual WASM tick flow in wasm-force-demo.

## Proposed Unified Model

### Core Types

```purescript
-- Attribute can be in one of these control modes
data AttributeMode a
  = Static a                           -- Set once
  | Transitioning (TransitionSpec a)   -- Animating to target
  | SimulationControlled               -- Hands off, physics owns this
  | TransitionThenSimulation           -- Enter: animate, then release to sim
  | SimulationThenTransition           -- Exit: release from sim, then animate out

-- Position specifically needs clear ownership
data PositionMode
  = StaticPosition          -- Set once, don't touch
  | TransitionPosition      -- Animate position (standalone, no sim)
  | SimulationPosition      -- Physics controls position
  | DataDrivenPosition      -- Position from data (tree layout computes it)

-- Tick source abstraction
data TickSource
  = RAF                    -- requestAnimationFrame (standalone transitions)
  | D3Force D3Simulation_  -- D3 force simulation tick
  | WASMKernel WasmHandle  -- Rust/WASM force kernel tick
  | Manual                 -- Test harness / debugging
```

### AST Integration

Current:
```purescript
type JoinBehavior datum =
  { attrs :: Array (Attribute datum)
  , transition :: Maybe TransitionConfig
  }
```

Enhanced:
```purescript
type JoinBehavior datum =
  { initialAttrs :: Array (Attribute datum)     -- Starting state
  , targetAttrs :: Array (Attribute datum)      -- End state
  , positionMode :: PositionMode                -- Who controls cx/cy?
  , transitionConfig :: Maybe TransitionConfig  -- Animate non-position attrs
  }
```

### Transition Engine Choice

```purescript
data TransitionEngine
  = D3Transition       -- Current: JS-driven, d3-ease
  | CSSTransition      -- Browser compositor, hardware accelerated
  | TickEngine         -- Our pure PS Engine, simulation-compatible
  | Automatic          -- Interpreter chooses based on context
```

**When to use which:**

| Engine | Best For | Limitations |
|--------|----------|-------------|
| D3Transition | Standalone element animations | Not sim-compatible |
| CSSTransition | Simple opacity/transform | Not sim-compatible, limited easing |
| TickEngine | Sim-integrated, testing | More PS overhead |
| Automatic | Let interpreter decide | Magic = debugging pain |

## Type-Level Enforcement Ideas

Could we use phantom types to prevent invalid combinations?

```purescript
-- Element tagged with its control mode
data Element (mode :: PositionControl) = Element { ... }

data PositionControl = Static | Transitioning | Simulated

-- withTransition only works on non-simulated elements
withTransition
  :: forall m datum
   . TransitionConfig
  -> Element Static datum  -- Can't call on Simulated!
  -> Array (Attribute datum)
  -> m Unit

-- addToSimulation changes the type
addToSimulation
  :: Element Static datum
  -> Simulation
  -> Element Simulated datum
```

This would make invalid states unrepresentable at compile time.

## Relationship to Coordinated Interaction Framework

The broader vision (from d3-dependency-reduction.md) includes:
- Brush-and-link
- Coordinate Hover
- Synchronized zoom/pan
- Shared selections

All of these involve **coordinated state changes across components**. Transitions are just one kind of coordinated change. A unified model should consider:

- How does a brush selection trigger transitions in linked views?
- How does a coordinated hover share state without triggering full re-renders?
- How do multiple simulations synchronize?

## Next Steps

1. **Document WASM tick flow** - How does wasm-force-demo actually work?
2. **Prototype PositionMode** - Add to AST, see what breaks
3. **Type-level experiment** - Can phantom types enforce ownership?
4. **Inventory current transitions** - Exactly which attrs are transitioned where?
5. **Design session** - Brainstorm unified tick coordinator

## References

- `docs/kb/plans/d3-dependency-reduction.md` - Overall D3 reduction plan
- `PSD3.Transition.Engine` - New pure PS transition engine
- `PSD3.Transition.Tick` - Easing and interpolation primitives
- `PSD3.Internal.Transition.FFI` - Current d3-transition bindings
- `PSD3.Internal.Capabilities.Transition` - TransitionM typeclass
