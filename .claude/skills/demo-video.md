# demo-video — recording a showcase as a video

Produce a narrated screen-recording of a showcase, to embed on the site
instead of keeping a live backend running for it.

## When to use this

Under the 2026-07-30 showcase policy there are three classes of exhibit:

| Class | Treatment |
|---|---|
| Static, no backend | **Stays live** on Cloudflare Pages |
| Backend-dependent | **Video** — this skill |
| The Docker fleet | Test bed + Tailscale Funnel on request |

Reach for a video when the exhibit needs a server, a rig, or a machine
that can't live in a browser tab. Don't make a video of something that
would happily deploy static — the Morphism Zoo needs no backend, so it
stays live.

Provenance: this is the Kibitzer pipeline, generalised. The originals are
worth reading before your first one — `kibitzer/docs/video-beat-sheet.md`,
`kibitzer/docs/vo-take4-final.md`, `kibitzer/video/capture-driver.js`,
`kibitzer/video/opening.html`.

## The method: VO-first

**Record the narration first, then retime the app to the narration.** Not
the other way round.

The temptation is to drive the app, then talk over the recording. That
fails: you end up either rushing the words to catch a transition or
padding to fill a dwell, and it sounds like it. Recording voice first
means the read is unhurried and natural, and the app — which is software,
and infinitely patient — bends to fit.

The consequence is that the whole capture is **one deterministic pass**.
No editing the app's timing afterwards, because the timing was computed
from the audio.

---

## 1 · Write the beat sheet

`docs/video-beat-sheet.md`. Number the beats (B1, B2, …). Each beat gets:

- `SHOT` — what's on screen
- `ACTION` — what the driver does
- `> **VO (Bn):**` — the words, in a blockquote

Head the file with the **master state**: the exact URL, seed, and
parameters that reproduce the run. Kibitzer's was
`http://localhost:3026/?seed=768896&players=6`. Without this you cannot
re-record a beat later, and you will need to.

**Ground-truth every factual claim before you read it aloud.** Kibitzer's
beat sheet carries an appendix verifying each per-event assertion, and
bolds the facts not to fudge. A video is not a REPL — an error is
expensive to fix and permanent once published.

Write for the voice you actually have. First person, unhurried. Read a
draft aloud before recording; anything you stumble over is badly written,
not badly read.

## 2 · Record the VO

Read the `> VO` blocks straight through. Keep the takes; Kibitzer's
final cut was take 4, and its shape came from take 3's unscripted spine
with hard facts spliced back in from the scripted version.

Then **measure each segment's duration in milliseconds.** Those numbers
are the input to the next step.

## 3 · Retime the driver

Copy `.claude/skills/demo-video-capture-driver.js` next to the showcase
as `video/capture-driver.js` and fill in:

1. The **selector map** — the app's tabs, buttons, and readouts. This is
   the only genuinely per-app part.
2. The **`T` block** — one entry per beat, set from the measured VO
   durations. Everything else derives from these.

Then rehearse at half speed: `DEMO.speed = 2; DEMO.play()`. Watch for
beats that land early or late and adjust `T` only — never sprinkle
timing constants through the body.

## 4 · Capture

- Serve the app at the master-state URL and let it settle.
- Paste the driver into the console.
- **Close the console**, so no devtools appear in frame.
- Press `0` to start (the driver installs a keydown handler for exactly
  this reason) and start your screen recorder.
- One pass, no stopping. If it goes wrong, reload and go again — a clean
  second take is cheaper than an edit.

## 5 · Title card (optional)

`kibitzer/video/opening.html` is a self-contained animated title
sequence: fixed 1920×1080 stage, one deterministic JS timeline, retimed
by editing numbers in `buildTimeline()`. Record it the same way — play,
capture, hold on the final frame. It runs silent; narration starts on the
cut to the app.

## 6 · Assemble and publish

Cut the VO against the capture. Because the app was timed to the audio,
this should be alignment, not surgery.

**Host on YouTube**, same as Kibitzer. Then add the exhibit to
`site/polyglot/public/index.html`:

```html
<a class="exhibit" href="backends/<slug>/" data-backend="<backend>">
  <span class="exhibit__thumb"><img src="images/<slug>.jpg" alt="…" loading="lazy"></span>
  <span class="exhibit__pill exhibit__pill--video">Video</span>
  <span class="tile__badge tile__badge--<backend>">…</span>
  <h4>…</h4>
  <p>…</p>
</a>
```

`exhibit__pill--video` already exists in `style.css`. Keep the existing
`exhibit__thumb` image as the poster. The card links to the per-exhibit
page under `content/backends/`, where the full embed lives.

`index.html` and `style.css` are hand-authored and never touched by
`build.sh` — edit them directly.

---

## Gotchas

**Guard every loop.** Stepping "until the readout says E102" must also
have a hard iteration cap. A driver that hangs mid-capture wastes the
take *and* the narration sync.

**Read state, don't count clicks.** Kibitzer's driver checks a position
readout (`posText()`) rather than assuming N presses gets you to event N.
Clicks get swallowed; state doesn't lie.

**Same-origin iframes are drivable** — `iframe.contentDocument`, then
click by id. Wait for readiness in a poll loop rather than a fixed sleep.

**Let a page settle after a cut** before narration lands on it —
Kibitzer used a `holdAfterCut` of 1 s uniformly.

**Slow down for the payoff.** Kibitzer runs briskly through the midgame
(270 ms/step) then drops to 900 ms/step for the final few, and holds 20 s
on the completed result. The viewer needs time to see the thing you spent
the whole video setting up.

**Silence is allowed.** The Kibitzer end-card runs 9 s with no narration
at all.
