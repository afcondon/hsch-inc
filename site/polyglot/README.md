# site/polyglot — the new polyglot.purescri.pt

A static, content-first site for the PureScript **backend constellation**:
a splashy typographic landing, a showcase of the differential corpus, a
"writing a backend" resources hub, and one page per backend with author
credits and repo links.

## Build

```bash
./build.sh          # renders content/*.md + content/backends/*.md -> public/
```

Requires `pandoc`. The landing page (`public/index.html`) and `public/style.css`
are **hand-authored** and never touched by the build — only the markdown content
pages are generated.

## Serve locally

```bash
cd public && python3 -m http.server 3050   # http://localhost:3050
```

## Structure

```
build.sh                 pandoc pipeline (page shell inlined)
content/
  resources.md           the "writing a backend" hub
  backends/<slug>.md      one per backend (first line `# Title`)
public/
  index.html             hand-authored landing + POLYGLOT acrostic
  style.css              Swiss/typographic, light theme; acrostic treatment
  resources/             generated
  backends/<slug>/       generated
```

## Content sources

Backend pages and the resources hub are distilled from, and should stay in
sync with, the authoritative docs:

- `../../docs/backends/backend-comparison.md` — the family + divergence table
- `../../docs/backends/adding-a-backend.md` — the column-adding contract

## The acrostic

`POLYGLOT` spelled down a highlighted spine, each letter a *current* backend:
P·ureScript / n·O·de / er·L·ang / p·Y·thon / wasm·G·c / ju·L·ia / g·O / racke·T.
Lua, purescm, purescript-native and purs-backend-es live in the grid below
rather than on the spine.

## TODO before publish

- **Verify every attribution and repo URL.** Several backend pages carry a
  `(verify)` / `(confirm before publish)` marker — purescm authorship/repo,
  the katsujukou Wasm repo, the Lua repo, and Purkt (source from Fabrizio).
  See `docs/backends/backend-comparison.md` §"For the comparison site".
- The diff-strip on the landing is **illustrative** — wire it to real JSONL
  output from the differential suite.
- Optional: a few lines of JS so hovering an acrostic letter also lifts its
  tile in the grid below (currently the spine letters highlight on hover, but
  the cross-section link is not wired — the two live in separate sections).
- Decide deploy path (Cloudflare Pages target `polyglot.purescri.pt` /
  `polyglot.hylograph.net`) and whether to retire the old `site/website`.
```
