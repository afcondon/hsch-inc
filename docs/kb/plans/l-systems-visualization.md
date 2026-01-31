# L-Systems Visualization

**Status**: planned
**Category**: plan
**Created**: 2026-01-30
**Tags**: l-systems, recursion-schemes, hylomorphism, apomorphism, generative

## Summary

Implement L-system (Lindenmayer system) visualization as a showcase for Hylograph, demonstrating the deep connection between recursion schemes and generative graphics.

## The Hylomorphism Connection

An L-system is a textbook hylomorphism:

1. **Anamorphism (unfold)**: Apply production rules to expand an axiom string
   ```
   A → AB
   B → A

   Iteration 0: A
   Iteration 1: AB
   Iteration 2: ABA
   Iteration 3: ABAAB
   ```

2. **Catamorphism (fold)**: Interpret the string as turtle graphics commands
   ```
   F → move forward, draw line
   + → turn left
   - → turn right
   [ → push state (position, angle)
   ] → pop state
   ```

The composition unfold-then-fold is exactly a hylomorphism. This makes L-systems a perfect demonstration of Hylograph's conceptual foundation.

## Apomorphism for Infinite Scroll

The apomorphism (unfold with early termination) enables a compelling UX feature:

- **Lazy generation**: Only unfold enough iterations to fill the viewport
- **Scroll to reveal**: As user scrolls, unfold more structure on demand
- **Preserved continuation**: The "seed" for the next unfold is maintained

This would be a unique demo - most L-system visualizers compute everything upfront. An infinite, lazily-generated botanical structure that grows as you explore it.

## Continuous Parametric Drift

Beyond just revealing static structure, the L-system could **vary as you scroll**:

- **Angle drift**: Turn angle slowly changes (e.g., 25° → 27° over scroll distance)
- **Stochastic rules**: Production rule selection has probabilities that shift
- **Length scaling**: Segment length varies with scroll position
- **Branching probability**: Deeper = more/fewer branches based on scroll

This makes scrolling feel alive - you're not just exploring a pre-computed tree, you're watching it evolve. The structure at the top would look subtly different from the bottom, creating a gradient of forms.

Could even tie the drift to scroll velocity - fast scrolling produces wilder variation, slow scrolling is more stable.

## Implementation Approach

### Core Types

```purescript
-- L-system grammar
type LSystem =
  { axiom :: String
  , rules :: Map Char String
  , angle :: Number  -- turn angle in degrees
  }

-- Turtle state
type TurtleState =
  { x :: Number
  , y :: Number
  , angle :: Number
  }

-- Rendered segment
type Segment = { x1, y1, x2, y2 :: Number }
```

### The Hylomorphism

```purescript
-- Unfold: expand grammar
expand :: Int -> LSystem -> String
expand n sys = iterate (applyRules sys.rules) sys.axiom !! n

-- Fold: interpret as graphics
interpret :: Number -> String -> Array Segment
interpret angle = execState turtle initialState
  where
  turtle = traverse_ interpretChar

-- Hylomorphism composition
render :: Int -> LSystem -> Array Segment
render n sys = interpret sys.angle (expand n sys)
```

### Apomorphism Variant

```purescript
-- Lazy expansion with viewport bounds
expandUntil :: (Array Segment -> Boolean) -> LSystem -> Array Segment
expandUntil viewportFilled sys = apo coalg (sys.axiom, [])
  where
  coalg (str, segments)
    | viewportFilled segments = Left segments  -- terminate early
    | otherwise = Right (step str segments)    -- continue unfolding
```

## Classic L-Systems to Include

1. **Algae** (Lindenmayer's original): Simple growth pattern
2. **Fractal Plant**: Bracketed, organic branching
3. **Dragon Curve**: Space-filling fractal
4. **Sierpinski Triangle**: Classic fractal
5. **Hilbert Curve**: Space-filling, locality-preserving

## Visual Design

- **Generative uniqueness**: Each visit produces slightly different result (randomized angles/lengths within bounds)
- **Botanical aesthetic**: Organic colors, slight line weight variation
- **Possibly**: Tie generation seed to external data (git hash? timestamp?)

## Data-Driven Variant

Could the L-system grammar itself be derived from data?

- Production rules from git branch patterns
- Axiom from file structure
- Angle from code metrics

This would make it both generative AND data visualization - truly novel.

## Dependencies

- Hylograph-selection (HATS rendering)
- Possibly hylograph-simulation for physics-based layout variants

## Success Criteria

1. Multiple classic L-systems rendered correctly
2. Infinite scroll working via apomorphism
3. Clear pedagogical connection to hylomorphism shown in UI
4. "Different every time" generative aspect
5. Optional: data-driven grammar derivation

## Related

- [Recursion Schemes as Visualization Primitives](../research/recursion-schemes-visualization.md)
- Hylograph naming/branding (hylomorphism connection)
