# The Demo-Sites Archipelago

*2026-07-16 — planned with Claude in the session following the jtms-sudoku demo build.*

## Motive

The hylograph-demos landing page has outgrown its title. Its nine tiles are
three different kinds of thing: demos **of** Hylograph (Fold, Forces, Layouts,
Anscombe), demos where Hylograph is merely the **lens** on another library
(Honeycomb and Decomposition demo the graph library; Explainable Sudoku demos
purescript-jtms), and **code typography** (Sigil; Type Classes as the bridge) —
whose siblings (Elements of PureScript Style, the-prelude) aren't even on the
page. Meanwhile the design has never sat right: the isometric tiles float in
undifferentiated whitespace — a map with no geography.

The underlying value of the demos repo — extracting demos from library repos so
libraries stay dependency-pure — holds. The move is to **replicate that pattern
per constellation** rather than pile everything into one page.

## The shape: a gateway above an archipelago

**Decided 2026-07-16 (Andrew):** two-level structure.

- **The gateway** — the existing landing page, keeping the Holy Tree hero, but
  stripped to a hall of portals: one tile per island, each tile showing that
  island's woodcut hero. No demo tiles at this level.
- **The islands** — one category page per constellation, each hero'd by one
  variant from the platonic-solids woodcut series, with its own isometric
  plaza of demo tiles plus a portal back to the gateway (and side-doors to
  sibling islands).

Conscious nod to Monument Valley chapter transitions (already implicit in the
tree-hero + iso-tile design). Same DNA across heroes = family resemblance;
lithograph vs woodcut distinguishes gateway from islands.

**Birth path:** the whole structure starts as a multi-page site inside the
existing `purescript-hylograph-demos` repo (gateway at `site/`, islands as
subdirectory pages). Islands migrate to their own repos later; portals repoint
cross-domain. No repo surgery required before the design can be evaluated.

## The art collection (all under `/Volumes/Crucial4TB/Photos/MidJourney/`)

| Series | Where | Count | Role |
|---|---|---|---|
| *A tree whose fruits are platonic solids, woodcut by MC Escher* | `woodcut/` | **17** | The hero family — one variant per island. Range: stark black-ground woodcuts → warm ochre icosahedra → sepia cube-tessellations. Same DNA, distinct identities. |
| *The Holy Tree of Data Visualization, lithograph by MC Escher* | `data-visualization/` | 2 | Current hylograph hero (tower-in-tree) + sibling (tree on pier over water). |
| *Centre Pompidou lithograph by MC Escher* | `escher/` | 1 | Candidate Scriptorium hero (impossible courtyard). |
| *Sagrada Familia fisheye lithograph / fractal woodcuts* | root + `woodcut/` | 1+4 | Spare heroes. |
| *Data-visualisation treemaps* in Art Deco / Art Nouveau / Beardsley / Rams / German Expressionist idioms | `data-visualization/`, `art-deco/`, `art-nouveau/` | 4 each | District emblems / section headers. |

Archive facts: 7,709 MidJourney images, indexed in the archive
`file_manifest.db` (mini) but with zero keywords in the photo `catalog.db` —
the ~100-subfolder prompt taxonomy is the only tagging. A browse surface for
this is now wished-for on Infovore (Marginalia #5, note 2026-07-16).

## The islands

1. **Hylograph** — existing `purescript-hylograph-demos` repo, keeps the Holy
   Tree hero. Tiles: Hylographic Fold, Force Playground, Layout Gallery,
   Anscombe's String Quartet. Plaza reorganised into a true tiled ground plane.
2. **Scriptorium** (code typography; name TBD) — new repo, likely under
   `code-typography/`. Tiles: Sigil, Type Classes (the bridge tile — sits at
   the portal edge facing Hylograph), Elements of PureScript Style (outbound),
   the-prelude (outbound), Specimen side-car sites as they appear.
3. **Reasoning / Foundations** (name TBD) — new repo. Tiles: The Honeycomb +
   Decomposition Explorer (graphs-extra), Explainable Sudoku (purescript-jtms /
   Baskerville). Libraries that Hylograph draws but that don't depend on it.
4. **Polyglot** — future island; demos still WIP. Gets a portal when ready.

Tiles may be **dual-listed during transition** (e.g. Honeycomb visible from
both Hylograph and Reasoning) — portals make cross-listing natural.

## Portal + design mechanics

- Shared visual grammar vendored into each repo (one small CSS file + tile
  markup conventions): iso plaza with an actual diamond-grid ground plane,
  always-visible small labels, district tints, hero grounded into the plaza
  (fade the frame; roots meet tiles).
- **v1 portals**: styled doorway tiles, plain `<a>` links between sites.
- **v2 portals**: cross-document View Transitions API (Chrome/Safari support;
  progressive enhancement) for the Monument-Valley chapter-turn feel.
- Each island: spago workspace, demos bundle to `docs/`, GitHub Pages, same
  Makefile pattern as hylograph-demos.
- Hero/thumbnail assets duplicated per repo (small, static — simpler than a
  shared assets repo).

## Sequencing and gates

1. **graphs-extra republish** (session booked 2026-07-18) — unblocks the
   Reasoning island AND the jtms-sudoku ship chain (and lets jtms drop its
   local Sudoku.Matching).
2. **purescript-jtms goes public** — forces the Baskerville rename decision.
3. **Specimen session** (booked 2026-07-17) — its side-car sites become
   Scriptorium tiles; accordion-folded instances idea lands there.
4. **Hero-selection pass** — Andrew picks a platonic-solids woodcut per island
   from the 17-variant contact sheet (delivered 2026-07-16).
5. **Gateway + islands mockup** — all inside `purescript-hylograph-demos`:
   gateway page (Holy Tree + portal tiles), plus island pages for Hylograph /
   Scriptorium / Reasoning, each with its woodcut hero and plaza. Evaluate in
   browser before any repo split is committed.

## Open decisions (Andrew's)

- Which woodcut goes to which island.
- Whether Honeycomb/Decomposition move or dual-list.
- Repo names and locations for the eventual island repos.
- How far the portal conceit goes (v1 links vs v2 view-transitions vs a real
  "explorable" with shared world geometry).

## Decided

- Two-level shape: Holy Tree lithograph = gateway landing; one platonic-solids
  woodcut per island/category (2026-07-16).
- Birth inside the existing demos repo; repo split deferred until the design
  proves itself (2026-07-16).
- Gateway = **the museum in plan view**: inline-SVG architect's floor plan,
  rotunda + wings in enfilade, every room a clickable demo, woodcut plates
  hung over their wings as portals (2026-07-16, "Perfect!").
- Wing names ride the shared GRAPH morpheme, typographically emphasised
  (2026-07-16): **Data Visualisation & GRAPHics** (west), **Code
  TypoGRAPHy and Style** (east), **GRAPHs and Chains of Reason** (south).
  URL slugs stay hylograph/ scriptorium/ reasoning/.

## Future wings

- **The Concert Hall** — a music wing for Atlantis (the live-coding rig:
  purerl-tidal / Calypso / DeepStar) and Producing With Your Feet. Andrew
  floated it 2026-07-16; the plan-view gateway makes adding a fourth wing a
  natural extension (north side is free — the tree occupies it visually, so
  more likely north-east/north-west diagonals or a second storey).
