# Polyglot PureScript — opening titles (video 0)

One self-contained file, **`manifesto.html`** — no CDN, no fonts to fetch, no
network requests of any kind. Two cuts inside it:

| cut | length | how to play | purpose |
|---|---|---|---|
| **manifesto** | ~86 s | open the file (auto-plays); key **0** replays | the argument, narrated over |
| **sting** | ~9.5 s | key **9**, or open `manifesto.html?sting` | silent; tops all thirteen videos |
| **cue take** | as long as you talk | key **c**, or `manifesto.html?cue` | measuring mode — see below |

## How it is built

A **wide stage** (7680×1080 — four 16:9 screens side by side) is seen through
a fixed 1920×1080 frame, scaled to the viewport by `fit()`. The **camera** is
a CSS transform transition on `#stage` (`cam(x, y, scale, dur)` — translate +
scale, origin 0 0). Camera stops: **A** = x 0 (the wish → the wall),
**B** = x 1450 (bypass, breach, flood), **C** = x 3840 (two gates converging
on one resolution), **D** = x 5760 (the conclusion). After the coda the
camera **pulls back** to `translate(0, 405) scale(.25)` — the whole path as a
hairline-framed band across the cream. That poster frame is the thumbnail.

Nine nodes: the wish (illuminated **twice** — it is also the path), the wall,
the bypass, the gate opens, gate two, gate three, one resolution (both gates'
arrows converge on it), the conclusion, the coda.

No `requestAnimationFrame` anywhere and no `scrollTo` — all motion is CSS
transitions/keyframes fired by `setTimeout`, so a hidden tab degrades to
end-states instead of hanging, and `behavior:'smooth'` never enters into it.

## Cue mode — the take drives the animation

`?cue` (or key **c**) turns the file into a measuring instrument. You advance
each beat with **SPACE** while narrating; the page records when you pressed.
The retime is then an *output* of the take rather than something recovered
from the audio afterwards.

When the last beat ends it prints — to the console, to `window.RETIME`, and
into the HUD as selectable text — two things:

1. a **paste-ready `T{}`**, ready to replace the block in this file;
2. a **JSON cue log** (`{beat, key, startMs, durMs, flushed, unsized}`) to
   join against a Whisper transcript, so each beat carries the sentences
   actually spoken inside it, not just a duration.

**Timebase.** The take starts on your **first press**, so beat 1 is `t0` for
both clocks. Subtract the transcript's first speech onset and the two share
an origin. The emitted `T{}` adds `LEAD` (= the original 2 s pre-roll) back
on, so the cold open survives — otherwise the first sentence would land at
`t = 0`.

**The flush rule.** Cue early and the outgoing beat's unfired entries fire
*at once* rather than queueing, so the picture stays in the right state. Each
flush is counted per beat and reported: a flush means the motion is slower
than the sentence over it, which is exactly the sort of thing worth knowing.

**Two beats are deliberately unsized** — `negspace` and `likewhat` have no
animation at all yet, and their measured durations are the most valuable
numbers the take produces. They are flagged `✱` in the report. Note that
`likewhat` provisionally owns `camC` + `fan`, putting the three motivations
over the runtime fan — a hypothesis the take tests, and a candidate fix for
the fan's ~2 s of unnarrated motion.

> ⚠️ **The window must be focused.** An unfocused tab clamps `setTimeout` to
> ~1 s, which quantises the very durations being measured. Spacebar needs
> focus anyway so it is mostly self-enforcing, but *start the recorder first,
> then click into the browser*. The mode samples `document.hasFocus()` during
> the take and prints a warning rather than emitting quiet garbage — a `blur`
> listener would not do, since a take begun in an already-unfocused tab never
> fires one.

Editing `CUES[]` is how you change the beat list; nothing in
`buildManifesto()` needs to know about cue mode. Each cue owns every timeline
entry from its own start to the next cue's, so motion-led phases (`travel`,
`camB`, `fback`, `camC`, `fan`, `camD`, `pull`) keep their built-in offsets
and ride the beat that owns them.

## Retiming (this will happen, against the recorded voiceover)

Everything is in **`T{}`** — module-level, just above `buildManifesto()`, so
a cued take reads the same object it rewrites. One number per narrated
sentence or camera move, in milliseconds. Intra-phase offsets are written
`T.x + n`, so moving a phase key moves the whole phase. The sting is `ST{}`
in `buildSting()`. Nothing else in the file carries phase timing.

- `window.SPEED` (or `?speed=4`) divides all timeline delays **and** camera
  durations for rehearsal. CSS micro-durations (0.2–1.4 s blooms and slams)
  do not scale; at 4× they overlap a little — rehearsal only.
- `?still` settles on the pulled-back poster in ~3 s (thumbnail export).
- Recording: Chrome fullscreen, tab visible. The UI buttons hide while
  playing (`body.playing`) so they never land on camera; mouse-move brings
  them back.

## The watercolour

JS port of `Onion/Watercolour.purs` (Tyler Hobbs method): a 12-gon base is
recursively subdivided — each edge midpoint displaced along the edge normal
by `gaussian × scale × edgeLength`, decaying 0.75× per depth — and stacked
10–26 variants deep at fill-opacity ≈ 0.045.

- **Seed: `SEED = 1969`**, via mulberry32 (integer ops — byte-identical on
  every run and machine). Each blob has a fixed per-blob offset in the
  `WASHES` table, so takes are identical and reordering the table changes
  nothing.
- Geometry is generated **once** per `play()`; animation only touches
  opacity/transform (per-path `transition-delay` stagger = pigment
  accumulating; inner-group scale = the bloom).
- **The pooling beat** lives in `w_pool` (WASHES) + `clipPath#clipWall`: the
  blob's base is clamped to spill past the wall face at x = 1601 and the
  whole group is clipped there, so the layer stack banks up and darkens at
  the masked edge — pigment against tape. At the gate-open beat it gets
  `.surge` (opacity × 1.45) before the chunk is knocked out.
- **The flood-back** is `w_fb1..3` + `w_wish2`: the same pigment turning
  west after the breach; the camera follows it home and the wish
  re-solidifies (second illumination + the "so write each piece where it
  belongs" clause).
- The **sting** reuses the conclusion bloom's seed offset (30) and the same
  generator/palette — same material, recentred.

## Palette (60s stock — deliberately not Kibitzer's red or the house vermilion)

| role | value |
|---|---|
| paper | `#f2ede2` |
| ink | `#211d16` |
| prussian blue — the pigment | `#254a6f` |
| ochre — the price | `#b3831c` |

## Headroom

`AMBIENT[]` (just below `buildManifesto()`) is a separate layer of
near-subliminal language marks (λ, ::, →, ∀ at 7% ink). Add marks in the
`typeLayer` and entries in `AMBIENT[]` — they merge into the timeline without
touching `T{}`. Quiet zones on the stage: screen 1 lower-left
(x 150–800, y 650–950) and the corridor x 2700–3900, y 620–950.

## Verification note

Headless Chrome (`--headless=new --virtual-time-budget=N --screenshot`) is
how the stills in this directory's history were checked. Caveat: mid-sequence
captures under virtual time under-report *in-flight* CSS transitions (flats
can read pale); end states and real playback are correct. Use `?still` for
the poster, and trust a live tab for motion.
