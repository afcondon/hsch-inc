# Minard Vision

**Code Cartography for the AI Era**

## The Two Problems

### 1. Understanding Core Concepts

When approaching an unfamiliar codebase, you need to build a mental model:
- What are the key abstractions?
- How do they relate to each other?
- What patterns are used consistently?
- Where is the complexity concentrated?

This is traditionally done by reading documentation (if it exists), grepping around, and gradually building intuition. It's slow and error-prone.

### 2. Keeping Up with LLM Change Sprees

Modern AI-assisted development creates a visibility problem unique to our time:

| Before LLMs | With LLMs |
|-------------|-----------|
| Changes are small, deliberate | Changes are voluminous, fast |
| Human tracks changes mentally | Too many changes to track |
| Refactors are planned events | Refactors happen mid-conversation |
| Dead code accumulates slowly | Dead code appears in bulk |

The human loses situational awareness. The LLM loses it between sessions. Nobody knows the true state of the codebase.

**Minard's thesis**: These problems have the same solution—rich, multi-dimensional visualization of code structure, relationships, and health metrics.

## The Views

### Currently Implemented

#### 1. Module Force Graph (Minard Frontend)
**What it shows**: Modules as nodes, imports as edges, force-directed layout
**Questions answered**:
- What are the high-connectivity hubs?
- Which modules are isolated?
- What are the natural clusters?

#### 2. Package Treemap (Minard Frontend)
**What it shows**: Hierarchical view of packages → modules, sized by LOC or declaration count
**Questions answered**:
- Where is the code mass?
- Which packages dominate?
- What's the module distribution within packages?

#### 3. Site Explorer (Route Analysis)
**What it shows**: Defined routes vs reachable routes, orphan detection
**Questions answered**:
- Are all routes reachable from navigation?
- Are there orphan pages?
- What's the navigation structure?

#### 4. Type Explorer - Type Graph
**What it shows**: Types as nodes with role-based coloring, relationships as edges
**Questions answered**:
- What type classes exist? Which types implement them?
- Which types are central to the design?
- Are there isolated types with no relationships?
- What's the instance coverage landscape?

#### 5. Type Explorer - Type Classes Splitscreen
**What it shows**: Interpreter × Expression matrix + Type class cards with donut charts
**Questions answered**:
- Which interpreters implement which expression classes?
- What's the coverage gap?
- How many instances does each type class have?
- Which type classes have the most/fewest methods?

### Planned / Brainstormed

#### 6. Change Heatmap
**What it shows**: Modules colored by recent change frequency, sized by change magnitude
**Questions answered**:
- Where is active development happening?
- What's been touched in the last N commits?
- Are there unexpected hotspots?
**Data source**: Git history, already in database

#### 7. Coupling Matrix
**What it shows**: Module × Module grid, cell intensity = coupling strength
**Questions answered**:
- Which modules are tightly coupled?
- Are there unexpected dependencies?
- What would break if I changed module X?
**Data source**: Import graph, call graph

#### 8. Dead Code Treemap
**What it shows**: Treemap of unreachable/unexported code, colored by age
**Questions answered**:
- How much dead code exists?
- Where is it concentrated?
- When did it die? (git history of last meaningful use)
**Data source**: Export analysis, call graph reachability

#### 9. API Surface View
**What it shows**: Exported declarations grouped by module, with usage counts
**Questions answered**:
- What's the public API surface?
- Which exports are never used externally?
- What's the API complexity per module?
**Data source**: Declarations + import analysis

#### 10. Test Coverage Overlay
**What it shows**: Any existing view with coverage data overlaid (red/green/yellow)
**Questions answered**:
- What's tested vs untested?
- Where are the coverage gaps?
- Are the complex modules well-tested?
**Data source**: Test coverage reports (needs integration)

#### 11. Proof Coverage View (Liquid PureScript)
**What it shows**: Declarations with refinement types, verified vs unverified
**Questions answered**:
- What properties are proven?
- What's the verification frontier?
- Where are the trust boundaries?
**Data source**: Liquid PureScript output (future)

#### 12. Dependency Age/Health
**What it shows**: Package dependencies colored by age, security status, deprecation
**Questions answered**:
- What needs updating?
- Are there security concerns?
- What's abandoned/maintained?
**Data source**: Registry metadata, security advisories

#### 13. Call Graph (Function Level)
**What it shows**: Function → Function call relationships for a focused area
**Questions answered**:
- What does this function call?
- What calls this function?
- What's the call depth?
**Data source**: CoreFN analysis (already extracted)

#### 14. Time-Lapse View
**What it shows**: Animated progression of codebase over git history
**Questions answered**:
- How did the architecture evolve?
- When did complexity spike?
- What was the growth pattern?
**Data source**: Git history + snapshots at commits

#### 15. Diff Impact View
**What it shows**: Given a pending change, what's the blast radius?
**Questions answered**:
- What depends on what I'm changing?
- What tests should I run?
- Is this change isolated or far-reaching?
**Data source**: Dependency graph + proposed changes

#### 16. LLM Session Delta
**What it shows**: What changed since the start of this Claude session?
**Questions answered**:
- What files were created/modified/deleted?
- What's the net change in LOC, declarations?
- Did we create dead code?
- Did we break any dependencies?
**Data source**: Git diff from session start marker

## View Categories

### For Understanding Core Concepts
- Type Explorer (Type Graph, Type Classes)
- Module Force Graph
- Package Treemap
- API Surface View
- Call Graph

### For Tracking LLM Changes
- Change Heatmap
- LLM Session Delta
- Diff Impact View
- Dead Code Treemap
- Test Coverage Overlay

### For Code Health
- Coupling Matrix
- Dead Code Treemap
- Dependency Age/Health
- Test Coverage Overlay
- Proof Coverage View

### For Historical Analysis
- Time-Lapse View
- Change Heatmap

## Implementation Priority

### High Value, Low Effort (Do First)
1. **Change Heatmap** - Git data already loaded
2. **Dead Code Treemap** - Export analysis exists
3. **Coupling Matrix** - Import data exists
4. **LLM Session Delta** - Just git diff + existing views

### High Value, Medium Effort
5. **Test Coverage Overlay** - Needs coverage tool integration
6. **Call Graph (focused)** - CoreFN data exists, needs UI
7. **Diff Impact View** - Dependency data exists, needs diff parsing

### High Value, High Effort (Future)
8. **Proof Coverage View** - Requires Liquid PureScript
9. **Time-Lapse View** - Requires multiple snapshots
10. **API Surface View** - Needs export/usage cross-reference

## Design Principles

### Powers of Ten
Every view should support zoom levels from package-set to call-site. The user should be able to:
- Start at the overview
- Drill into interesting areas
- Jump back out
- Navigate laterally to related views

### Fog of War Metaphor
Use game-inspired visual language:
- Bright/saturated = well-understood, well-tested, recently touched
- Dim/desaturated = unknown, untested, stale
- Red = danger (dead code, high coupling, no tests)
- Green = healthy (tested, verified, low coupling)

### CLI + Viz Parity
Every visualization should have a CLI equivalent that the LLM can use:
```bash
minard coupling-report --module Data.Array
minard dead-code --since 2024-01-01
minard session-delta --from HEAD~10
```

Same data, different presentations. The human sees patterns; the LLM queries specifics.

### Composition
Views should compose. "Show me the coupling matrix, but only for modules touched this week" should be expressible.

## Success Criteria

Minard succeeds when:

1. **A new developer** can understand a codebase's architecture in 10 minutes instead of 10 hours
2. **A maintainer** can spot dead code and coupling issues at a glance
3. **An LLM** can query for specific structural facts without grepping
4. **A pair** (human + LLM) can track a refactoring session's impact in real-time
5. **Anyone** can answer "what would break if I changed X?" before changing X

## Limitations: What Visualization Can't See

### "Almost Dead" Code

Static analysis can detect truly dead code (unreachable, unexported, never called). But there's a category of code that's technically alive but effectively obsolete:

- Prototypes that worked but were superseded by a better approach
- Legacy code kept "just in case" but never actually exercised
- The old implementation still present alongside the new one
- Experimental code that got merged but never productionized

**Why this is hard to visualize**: It requires *intent*, not structure. The code compiles, it's reachable, it might even be called—but it represents a path not taken, a decision reversed, a migration in progress.

**Why humans see it better**: The human author remembers "we tried X but then did Y instead." They have the narrative of the codebase evolution. An LLM working session-to-session loses this context; static analysis never had it.

**Our position**: This is better addressed through *process* than visualization:

1. **Session worklogs** capturing "Explored But Not Pursued" and "Decisions Made"
2. **Git commit messages** with intent ("prototype", "superseded by X")
3. **Explicit annotations** when warranted:
   ```purescript
   -- | @status deprecated
   -- | @superseded-by Data.Graph.Algorithms
   module Data.Graph.OldAlgorithms where
   ```
4. **Periodic audits** (like `/fp-police`) that surface "this looks like an old approach"

If explicit tagging exists, visualization can consume it (gray out deprecated modules, draw supersession edges). But the *input* must come from human annotation—inferring intent from structure is a fool's errand.

The worklog habit is key: if "what did we decide NOT to do?" were queryable, it might be more useful than any amount of static analysis.

## Related Work

- **Gource** - Git history visualization (time-lapse)
- **Code City** - 3D city metaphor for code structure
- **Sourcetrail** - Cross-reference navigation
- **Understand** - Static analysis visualization
- **CodeScene** - Behavioral code analysis

Minard differs by:
- First-class LLM support (CLI for AI, viz for human)
- PureScript-native (understands the type system deeply)
- Multi-scale navigation (Powers of Ten)
- Declarative visualization (Hylograph/HATS)

---

*"At least your death march will look good."*
