---
title: "The PureScript Libraries Ecosystem — Showcase Site"
category: plan
status: proposed
tags: [ecosystem, sigil, hylograph, showcase, website]
created: 2026-02-20
summary: "The Lonely Planet Guide to PureScript-landia" — an opinionated, beautifully presented guide to the PureScript library ecosystem, built with hylograph and sigil.
---

# The PureScript Libraries Ecosystem

## Vision

**The Lonely Planet Guide to PureScript-landia.**

Not Pursuit (which, since it includes everything, emphasizes nothing). Not documentation. An opinionated, curated guide to the libraries that make PureScript worth learning — with diagrams, sigil-rendered type signatures, compelling examples, and memorable framing.

Two goals:
- **Selfish**: a frequently-consulted, compelling demo for hylograph and sigil
- **Altruistic**: learning Haskell/PureScript is hard enough that people over-invest in the language and under-invest in the libraries. The inverse of Python, where the libraries *are* the reason to learn. This site makes the case that PureScript's libraries are worth the climb.

Each section should lodge in the reader's head: a paragraph and an example that means when they encounter a situation, they think "oh right, I should reach for X." The aspiration is to impress on people that it's worth learning PureScript to have access to these killer libraries, much as it's worth learning Python for AI and data science.

## The Library Guide

### Foundational — "you can't avoid these, and you shouldn't want to"

#### 1. The Type Class Hierarchy
The intellectual backbone of PureScript. The Prelude type classes (Eq, Ord, Semigroup, Monoid, Functor, Apply, Applicative, Bind, Monad, etc.) and the algebraic tower (Semiring → Ring → Field). Counterexamples + Examples: concrete types that do and don't satisfy each class, making the abstractions tangible.

**Spark**: Phil Freeman's "Counterexamples of Type Classes" blog post, expanded into interactive DAGs with sigil-rendered nodes.

#### 2. Effect & Aff
PureScript's effect system — the thing that actually makes "pure functional programming" practical. Effect (synchronous), Aff (asynchronous), the distinction between them, and why tracking effects in the type system catches real bugs. The row-polymorphic story.

#### 3. Optics (profunctor-lenses)
Lenses, prisms, traversals. "Once you learn it you can't go back." Transforms how you think about data access and modification. Show a before/after: nested record update without lenses vs with. The profunctor encoding and why it composes so cleanly.

### Workhorse Libraries — "reach for these weekly"

#### 4. Containers
ordered-collections (Map, Set), arrays, lists, NonEmpty. The well-typed data structure story. The Foldable/Traversable unification — write it once, it works on every container. When to reach for Map vs Object, Array vs List.

#### 5. Parsing
Parser combinators (purescript-parsing). Composable, type-safe parsing that makes regex look primitive. Also: language-cst-parser (the actual PureScript parser — yes, PureScript parses itself), tidy (the formatter). The story of parsers as first-class values that compose like functions.

#### 6. Argonaut & Codecs
Principled JSON serialization. The codec pattern: bidirectional, composable, type-safe. Contrast with the JavaScript approach ("just parse it and pray"). Show how a codec both encodes and decodes, and how codecs compose for nested structures.

#### 7. Numbers / Numeric Tower
Int, Number, BigInt and the Semiring → Ring → CommutativeRing → EuclideanRing → Field hierarchy. Why the algebraic structure matters (you get generic algorithms for free). Connects directly to the type class hierarchy section.

### Application Frameworks

#### 8. Halogen
THE PureScript UI framework. Component model, type-safe queries, subscriptions, the slot system. Why it's worth the learning curve over React wrappers. Show a component that would be painful in React but elegant in Halogen.

#### 9. HTTPurple
Server-side PureScript, including WebSockets. The full-stack story: same language, same type safety, client and server. Middleware, routing, request handling.

#### 10. routing-duplex
Bidirectional routing — parse URLs to routes and print routes to URLs with a single definition. Eliminates the class of bugs where your links don't match your routes. Elegant, small, and surprisingly useful.

### Techniques & Patterns

#### 11. FFI (Foreign Function Interface)
There's a Right Way and many Wrong Ways. The critical lesson: **never depend on the runtime representation of a PureScript value**. Even Claude gets this wrong, and so does everyone coming from JavaScript. Show the right patterns: opaque foreign types, typed wrappers, Effect-returning FFI functions. Show the wrong patterns and why they break.

#### 12. Run / Free
Extensible effects and interpreters. The finally-tagless / free monad story. Write your program as a description, then choose how to interpret it. Powerful for testing (swap in a mock interpreter) and for separating concerns.

#### 13. QuickCheck
Property-based testing. "Describe what should be true, let the machine find counterexamples." The shift from "test these specific cases" to "test these invariants." Show a property that catches a bug that unit tests would miss.

### Showcase

#### 14. Hylograph
Declarative visualization for PureScript. The site itself is the demo — every diagram, every interactive graph is built with hylograph. HATS (the AST), selections, force simulation, layout algorithms.

#### 15. Sigil
Type signature rendering. Every beautifully typeset class definition, method signature, and ADT declaration on the site comes from sigil. The colored type variables, constraint pills, arrow chains — sigil makes types legible.

#### 16. Haskell Ports
PureScript has access to the Haskell intellectual tradition. Libraries ported from Haskell (linear algebra, others) demonstrate that good ideas cross language boundaries. The porting process and what adapts well.

## Architecture

### Scaffolding-First Approach

The site can start as bare HTML + sigil and already look great. Sigil's typography carries the visual weight. Add hylograph flash incrementally — interactive DAGs, force graphs, animated transitions — as each section matures.

**Phase 0 (2 sessions)**: Static HTML pages with sigil-rendered type signatures, curated examples, and the guide text. No hylograph yet. Already a useful, good-looking site.

**Phase 1**: Add the Counterexamples interactive DAG (requires sigil SVG renderer). First hylograph integration.

**Phase 2**: Prelude type class map, package constellation. More hylograph.

**Phase 3**: Instance matrix, full lattice, zoom-dependent rendering. Polish.

### Site Structure

```
ecosystem.hylograph.net/           # or similar
├── index.html                     # Landing: "The Lonely Planet Guide to PureScript"
├── type-classes/                  # Section 1: The Type Class Hierarchy
│   ├── index.html                 # Overview + Prelude map
│   └── counterexamples/           # Interactive counterexamples article
├── effects/                       # Section 2: Effect & Aff
├── optics/                        # Section 3: Lenses, Prisms, Traversals
├── containers/                    # Section 4: Map, Set, Array, List
├── parsing/                       # Section 5: Parser Combinators
├── codecs/                        # Section 6: Argonaut & Codecs
├── numbers/                       # Section 7: Numeric Tower
├── halogen/                       # Section 8: Halogen
├── httpurple/                     # Section 9: HTTPurple
├── routing/                       # Section 10: routing-duplex
├── ffi/                           # Section 11: FFI Patterns
├── run/                           # Section 12: Run / Free
├── quickcheck/                    # Section 13: Property-Based Testing
├── hylograph/                     # Section 14: Hylograph
├── sigil/                         # Section 15: Sigil
└── ports/                         # Section 16: Haskell Ports
```

### Tech Stack

- **Rendering**: HTML + sigil for initial scaffold; hylograph (HATS) for interactive exhibits
- **Type rendering**: sigil HTML for static pages, sigil SVG for DAG nodes (once available)
- **Layout**: hylograph-layout (Sugiyama) for hierarchical graphs, hylograph-simulation for force-directed
- **Data**: curated — each section is hand-authored with selected examples and sigil-rendered signatures
- **Build**: spago bundle per interactive page, static HTML for guide pages
- **Hosting**: Cloudflare Pages or similar static hosting
- **Style**: Swiss/International Typographic Style — clean grids, generous whitespace, restrained palette, strong hierarchy through type scale

### Per-Section Template

Each library section follows a pattern:

1. **The pitch** — one paragraph that lodges in your head. "When you need X, reach for Y because Z."
2. **The key types** — sigil-rendered type class definitions or key type signatures. 2-4 types that define the library's API surface.
3. **The compelling example** — a concrete code snippet showing the library solving a real problem. Before/after if applicable.
4. **The diagram** (where applicable) — a type class DAG, a data flow, a component tree. Built with hylograph.
5. **The links** — Pursuit docs, source repo, key blog posts.

## Visual Design

### Palette

Light background (cream/warm white). Color coding per sigil conventions:
- **Indigo** (#6366f1) for type classes
- **Amber** (#d97706) for data types
- **Gold** (#edc948) for type synonyms
- **Rose** (#e15759) for foreign imports
- **Section accent colors** for navigation and headers

### Typography

- Body: Inter or system sans-serif
- Code/signatures: Fira Code (monospace), rendered by sigil
- Headings: strong weight, restrained — let the code be the star

### Layout

- Each section is a full page — not cramped
- Generous whitespace around sigil-rendered blocks
- Diagrams inline with text, not in separate "demo" panels
- Mobile-responsive (sigil blocks reflow; diagrams scale)

## Relationship to Other Projects

| Project | Relationship |
|---------|-------------|
| **purescript-sigil** | Every rendered type signature comes from sigil |
| **purescript-sigil SVG** | Required for interactive DAG nodes (Phase 1+) |
| **hylograph-selection** | HATS rendering engine for interactive exhibits |
| **hylograph-layout** | Sugiyama layout for type class DAGs |
| **hylograph-simulation** | Force layout for package constellation |
| **CodeExplorer/Minard** | Counterexamples article migrates from TypeExplorer |
| **purescript-polyglot** | Sister site; cross-links |
| **Pursuit** | Complementary — we link to Pursuit for API details, we provide the "why" and "when" |

## Success Criteria

- Static scaffold (HTML + sigil) for all 16 sections — readable, good-looking, useful
- At least 3 sections with interactive hylograph diagrams
- The counterexamples article with sigil-rendered DAG nodes as the flagship exhibit
- Memorable: a PureScript developer consults it when choosing libraries
- Persuasive: someone considering PureScript sees it and thinks "these libraries are worth the climb"
