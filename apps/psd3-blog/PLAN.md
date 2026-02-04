# PSD3 Blog Platform - Planning Document

**Status**: Brainstorming
**Created**: 2026-02-04

## Vision

A lightweight blogging platform for publishing content about the PSD3 library system, with first-class support for embedded Hylograph visualizations. The blog should:

1. Be easy to author (markdown-first, dynamic loading)
2. Support embedded interactive visualizations
3. Dogfood Hylograph/HATS for explanatory diagrams
4. Allow viz development in throwaway apps before incorporation
5. Use the visualization library itself for navigation (force layout index)

## Design Decisions

### 1. Dynamic Loading (DECIDED)

**Chosen: Dynamic runtime loading**
- Markdown files fetched at runtime
- Runtime markdown parser (marked.js)
- Viz components are compiled PureScript/Halogen
- No build step for content changes
- Low readership assumed - no caching concerns

**Rationale**: Simpler workflow, no intermediate files, edit markdown and refresh.

### 2. Three Types of Embedded Content

#### A. Named Viz Components: `{{viz:ComponentName}}`

Custom Halogen components developed in sandbox, then incorporated:

```markdown
Here's an interactive force simulation:

{{viz:BerkeleyAdmissions}}
```

The component `BerkeleyAdmissions` is a full Halogen component with its own state, events, etc.

#### B. Inline HATS Declarations (MetaHATS)

HATS code blocks that render as actual visualizations:

````markdown
```hats
svg { width: 400, height: 300 }
  ├── rect { fill: "steelblue", width: 100, height: 50 }
  └── circle { cx: 200, cy: 150, r: 40, fill: "coral" }
```
````

Reader sees:
1. Syntax-highlighted code (Prism.js with HATS theme)
2. Rendered visualization below/beside it

Like the Interactive HATS Explorer - write declaration, see result.

#### C. Regular Code Blocks (Prism.js)

Standard syntax highlighting for PureScript/Haskell examples:

````markdown
```purescript
renderNode :: Node -> HTML
renderNode node =
  HH.circle [ cx node.x, cy node.y, r 5.0 ]
```
````

Uses Prism.js with Haskell/PureScript theme matching blog colors.

### 3. Navigation: Force Layout Index (DECIDED)

The landing page / index is NOT a traditional blog listing. Instead:

- **Force-directed graph** of all articles
- **Nodes** = articles
- **Edges** = cross-references between articles (parsed from markdown links)
- **Visual style** similar to ForcePlayground
- **Click node** → navigate to article

This dogfoods Hylograph for the blog's own UX. Articles about related topics cluster together naturally.

**Implementation approach:**
1. Build step scans all markdown files for internal links
2. Generates graph data (nodes + edges)
3. Force layout renders at runtime
4. Clicking node → Halogen routing to article

### 4. Article Pages (DECIDED)

Individual articles are simple linear flow:
- Markdown content top to bottom
- Viz embeds inline where placed
- No grid layout complexity
- Responsive by default

### 5. Syntax Highlighting (DECIDED)

**Prism.js** with:
- Haskell/PureScript theme (colors matching blog)
- Custom HATS syntax definition (from Interactive HATS Explorer)
- Line numbers optional

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Runtime                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │  Halogen App │                                               │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      Router                              │    │
│  ├──────────────────┬──────────────────────────────────────┤    │
│  │                  │                                       │    │
│  │    /             │           /post/:slug                 │    │
│  │    ▼             │           ▼                           │    │
│  │ ┌────────────┐   │   ┌─────────────────────────────┐    │    │
│  │ │ ForceIndex │   │   │     ArticleViewer           │    │    │
│  │ │            │   │   │                             │    │    │
│  │ │ ○──○──○    │   │   │  fetch(/posts/slug.md)      │    │    │
│  │ │ │╲ │ ╱│    │   │   │         │                   │    │    │
│  │ │ ○──○──○    │   │   │         ▼                   │    │    │
│  │ │            │   │   │  ┌─────────────────────┐    │    │    │
│  │ │ click→nav  │   │   │  │   marked.js parse   │    │    │    │
│  │ └────────────┘   │   │  └─────────────────────┘    │    │    │
│  │                  │   │         │                   │    │    │
│  │                  │   │         ▼                   │    │    │
│  │                  │   │  ┌─────────────────────┐    │    │    │
│  │                  │   │  │  Render Pipeline    │    │    │    │
│  │                  │   │  │                     │    │    │    │
│  │                  │   │  │  text → HTML        │    │    │    │
│  │                  │   │  │  {{viz:X}} → slot   │    │    │    │
│  │                  │   │  │  ```hats → MetaHATS │    │    │    │
│  │                  │   │  │  ```ps → Prism      │    │    │    │
│  │                  │   │  └─────────────────────┘    │    │    │
│  │                  │   │                             │    │    │
│  │                  │   └─────────────────────────────┘    │    │
│  └──────────────────┴──────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Build Time                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  posts/*.md ────► graph-builder ────► graph-data.json           │
│       │              (Node)              (edges from             │
│       │                                   cross-refs)            │
│       │                                                          │
│       └────────────────────────────────► /public/posts/         │
│                    (copy)                                        │
│                                                                  │
│  src/**/*.purs ──► spago bundle ──────► /public/bundle.js       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
apps/psd3-blog/
├── posts/                        # Markdown content
│   ├── index.json                # Post metadata (generated)
│   ├── graph-data.json           # Cross-ref graph (generated)
│   ├── hats-introduction.md
│   ├── force-layouts-explained.md
│   └── building-metahats.md
│
├── sandbox/                      # Viz development
│   └── berkeley-viz/             # Throwaway app
│       ├── spago.yaml
│       ├── src/Main.purs
│       └── public/index.html
│
├── src/
│   ├── Main.purs                 # App entry
│   ├── Router.purs               # URL routing
│   ├── Blog/
│   │   ├── ForceIndex.purs       # Landing page force layout
│   │   ├── ArticleViewer.purs    # Markdown renderer
│   │   └── RenderPipeline.purs   # {{viz}}, ```hats, etc.
│   └── Viz/                      # Blog-specific viz components
│       ├── Registry.purs         # {{viz:Name}} → Component
│       └── BerkeleyAdmissions.purs
│
├── tools/
│   └── graph-builder.js          # Scans posts, builds graph
│
├── public/
│   ├── index.html
│   ├── bundle.js                 # Compiled app
│   ├── posts/                    # Served markdown
│   └── css/
│       ├── blog.css
│       └── prism-hats.css        # HATS syntax theme
│
├── spago.yaml
├── Makefile
└── PLAN.md                       # This file
```

## Viz Development Workflow

### Creating a new visualization

```bash
# 1. Create sandbox
make sandbox-new name=berkeley-viz

# 2. Develop in sandbox (hot reload)
cd sandbox/berkeley-viz
npm run dev
# ... iterate on visualization ...

# 3. When satisfied, promote to blog
make sandbox-promote name=berkeley-viz

# 4. Register in Viz/Registry.purs
# 5. Reference in post: {{viz:BerkeleyViz}}
```

### Inline HATS (no sandbox needed)

For simple diagrams, just write HATS directly in markdown:

````markdown
The tree structure looks like this:

```hats
group { class: "tree" }
  ├── circle { r: 20, fill: "root" }
  ├── line { ... }
  └── group { class: "children" }
      ├── circle { r: 15 }
      └── circle { r: 15 }
```
````

MetaHATS renders it inline - no separate component needed.

## Key Components

### 1. ArticleViewer

Fetches markdown, parses, renders with embedded content:

```purescript
-- Pseudocode
render state = case state.content of
  Loading -> spinner
  Loaded md ->
    let parsed = parseMarkdown md
        segments = splitOnEmbeds parsed
    in HH.div_ (map renderSegment segments)

renderSegment = case _ of
  TextSegment html -> HH.raw html
  VizEmbed name -> HH.slot (lookupViz name) unit
  HatsBlock code -> HH.slot _metahats unit (MetaHATS.component code)
  CodeBlock lang code -> HH.pre [ class_ "prism" ] [ HH.code_ [ HH.text code ] ]
```

### 2. ForceIndex

Force-directed graph of articles:

```purescript
type ArticleNode =
  { slug :: String
  , title :: String
  , tags :: Array String
  }

type ArticleEdge =
  { source :: String  -- slug
  , target :: String  -- slug (from cross-reference)
  }

-- Load graph-data.json, render with psd3-simulation
-- On node click: navigate to /post/:slug
```

### 3. VizRegistry

Maps `{{viz:Name}}` to Halogen components:

```purescript
lookup :: String -> Maybe (SomeHalogenComponent)
lookup = case _ of
  "BerkeleyAdmissions" -> Just (mkExists berkeleyComponent)
  "ForcePlayground" -> Just (mkExists forcePlaygroundComponent)
  _ -> Nothing
```

## Prior Art References

- **Simpson's Paradox** (`site/website/src/Page/Simpsons.purs`) - Grid layout, viz slots
- **Interactive HATS Explorer** - MetaHATS rendering, HATS syntax highlighting
- **ForcePlayground** - Force layout with interactive nodes

## Design Decisions (continued)

### 6. MetaHATS as Reusable Component (DECIDED)

Extract MetaHATS rendering as a reusable Halogen component during this work.
- Interactive HATS Explorer is feature-complete, won't retrofit
- Build the component here, potentially extract to library later
- Component takes HATS source string, renders code + visualization

### 7. Mobile: No Fallback (DECIDED)

Force layout works on mobile - no list fallback:
- Test thoroughly on mobile
- Ensure nodes are appropriately sized for touch
- Pinch-to-zoom if needed
- The force layout IS the navigation, not an optional enhancement

### 8. Visual Design: Tschichold Modernism (DECIDED)

Aesthetic inspired by **Jan Tschichold** and data visualization conventions:

- **Typography**: Clean sans-serif (Inter, IBM Plex Sans, or similar)
- **Layout**: Asymmetric, generous white space
- **Color**: Restrained palette - black text, white background, accent colors only for data
- **Chrome**: Minimal - no sidebars, no clutter, content-first
- **Grid**: Underlying structure but not visible
- **Headers**: Strong hierarchy, no decorative elements

The blog should feel like a well-designed academic paper or Tufte's books -
the visualizations are the attraction, typography supports them.

**Anti-goals:**
- No hero images
- No social share buttons
- No comment sections
- No newsletter popups
- No dark mode toggle (pick one and commit)

## Open Questions

1. **Graph builder implementation** - Node script pragmatic, PureScript if parsing gets complex

2. **Post metadata format** - YAML frontmatter seems natural:
   ```yaml
   ---
   title: Introduction to HATS
   date: 2026-02-04
   tags: [hats, tutorial, beginner]
   ---
   ```

## Next Steps

1. [ ] Scaffold basic Halogen app with router
2. [ ] Implement ArticleViewer with basic markdown (no embeds)
3. [ ] Add Prism.js syntax highlighting (with HATS syntax from Interactive Explorer)
4. [ ] Build MetaHATS component (HATS source → code + rendered viz)
5. [ ] Add `{{viz:Component}}` support with registry
6. [ ] Build graph-builder tool (Node script)
7. [ ] Implement ForceIndex with mobile-friendly touch targets
8. [ ] Design Tschichold-inspired CSS
9. [ ] Create first real post
10. [ ] Sandbox workflow tooling (make targets)

## Name Ideas

Still unnamed. Candidates:
- **psd3-blog** (functional)
- **hylograph-press** (reference to Hylograph)
- **inked-diagram** (anagram of something?)
- Leave unnamed until personality emerges
