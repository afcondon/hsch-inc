# Understanding Hylograph - Documentation Skeleton

**Status**: Draft for dialogue (v2 - benefit-led structure)
**Purpose**: Skeleton for the "Understanding" section of hylograph.net docs

---

## Hero Text

> **Type-safe data visualization for PureScript**
>
> Let the compiler catch your mistakes. Transform your ADTs, Maps, Sets, and Graphs directly into interactive visualizations without lossy conversion to untyped data.
>
> Build composable visualization components that are both reusable and customizable - the same component can render to DOM, generate accessibility descriptions, or produce documentation diagrams.
>
> Create animated, simulation-driven visualizations entirely under PureScript control. Clean integration with Halogen as a first-class part of your application.
>
> Write programs that generate visualizations. Extend layouts written in readable PureScript.

---

## 1. Type-Safe Visualizations

**Benefit**: The compiler catches invalid operation sequences. No runtime surprises, no defensive unit tests for visualization logic.

**What you get**:
- Compile errors when you try to set attributes on unbound data
- Compile errors when you forget to handle exiting elements
- Type inference guides you through the visualization lifecycle

*(Sidebar: How phantom types make this possible)*

---

## 2. Composable Components

**Benefit**: Build visualization components that are reusable across projects and customizable at the call site. PureScript's type system ensures components compose correctly.

**What you get**:
- Components with typed configuration
- Override defaults without breaking internals
- Compose small components into complex visualizations
- Share components as libraries with full type safety

*(Sidebar: Finally tagless and the expression problem)*

---

## 3. Programs That Write Visualizations

**Benefit**: Because specs are declarative data, you can generate them programmatically. Build visualization factories, template systems, or domain-specific generators.

**What you get**:
- Visualization specs are values you can manipulate
- Generate specs from database schemas, API responses, or config files
- Same spec renders to multiple outputs (DOM, accessibility text, diagrams)
- Test visualization logic without a browser

*(Sidebar: HATS and the hylomorphism insight)*

---

## 4. Real Data Types, Not JSON

**Benefit**: Visualize your actual domain types - ADTs, Maps, Sets, Graphs - without flattening to "JSON-shaped" data.

**What you get**:
- Pattern match on your sum types in attribute functions
- Use Map keys directly for data joins
- Graph structures stay graphs, not adjacency lists
- Refactor your types and the compiler tells you what visualizations need updating

*(Sidebar: The data join reimagined)*

---

## 5. Animations and Simulations You Control

**Benefit**: Build animated, physics-driven visualizations where PureScript owns the state. No callback hell, no mysterious mutations.

**What you get**:
- Declarative force composition (center, collide, links, gravity)
- Simulation state flows through your Halogen components
- Pause, resume, reheat simulations from your UI
- Transitions as data, not imperative sequences

*(Sidebar: Force simulation architecture)*

---

## 6. First-Class Halogen Integration

**Benefit**: Data visualization as a proper part of your application architecture, not a bolted-on widget.

**What you get**:
- Visualizations as Halogen components
- Bidirectional communication (clicks, hovers, selections)
- Visualization state in your component state
- Lifecycle management that makes sense

*(Sidebar: Subscriptions and declarative rendering)*

---

## 7. Layouts You Can Read and Extend

**Benefit**: Layout algorithms written in clear PureScript. Understand them, modify them, create new ones.

**What you get**:
- Tree, pack, treemap, partition layouts
- Sankey diagrams, chord diagrams, edge bundles
- Pure functions: data in, positioned data out
- Extend or customize without reverse-engineering

*(Sidebar: Pure computation and layout composition)*

---

---

## Appendices (Technical Deep Dives)

These sidebars expand on the "how" for readers who want to understand the mechanisms.

### A. Phantom Types and Selection Safety

**Status**: ✅ Verified - fully enforced at compile time for public API

The five selection states form a compile-time state machine:

| Operation | Required State | Output State |
|-----------|---------------|--------------|
| `select` | - | `SEmpty` |
| `joinData` | `SEmpty` | `JoinResult (SPending, SBoundOwns, SExiting)` |
| `append` | `SPending` | `SBoundOwns` |
| `setAttrs` | `SBoundOwns` | `SBoundOwns` |
| `remove` | `SExiting` | `Unit` |

Invalid sequences are compile errors, not runtime surprises.

---

### B. Finally Tagless and the Expression Problem

The expression problem: how do you add both new operations AND new data types without modifying existing code?

Finally tagless solves this with type classes as interpreter interfaces. Your visualization spec is polymorphic over the interpreter - the same code renders to DOM, generates accessibility text, or produces Mermaid diagrams.

This is also what enables true components: a component is a polymorphic function that works with any interpreter.

---

### C. HATS: Hylomorphic Abstract Tree Syntax

Visualization is fundamentally a hylomorphism:
- **Unfold**: data → tree structure (what elements exist, how they nest)
- **Fold**: tree → rendered output (DOM, text, diagram)

HATS is the intermediate tree. It's declarative (what, not how) and interpretable (multiple backends).

---

### D. Force Simulation Architecture

D3's force engine is excellent - we use it directly. But state ownership matters:
- D3 mutates node positions (it's good at this)
- PureScript observes and renders (we're good at this)
- Halogen manages the lifecycle (subscriptions, reheating)

Result: physics simulations that fit your application architecture.

---

### E. The Data Join Reimagined

D3's enter/update/exit pattern, but with types:
- `SPending`: new data needs elements created
- `SBoundOwns`: existing elements with current data
- `SExiting`: orphaned elements need removal

The compiler ensures you handle all three cases.

---

### F. Pure Layout Computation

Layouts are pure functions: `data → positioned data`. No DOM, no side effects.

This means:
- Test layouts without a browser
- Compose layouts (pack inside treemap)
- Serialize layout results
- Debug with simple logging

---

## Notes for Dialogue

**Reconciliation needed on**:
- [ ] Which interpreters are real vs aspirational?
- [ ] Is the hylomorphism framing accurate to implementation?
- [x] Are phantom types fully enforced or partially? **RESOLVED: 90% enforced at compile time**
- [ ] Which layouts are complete vs in-progress?

**Open questions**:
- [ ] Component story - what's implemented vs aspirational for v1?
- [ ] "Programs that write visualizations" - do we have examples to point to?
- [ ] Halogen integration - is hylograph-simulation-halogen the whole story?
