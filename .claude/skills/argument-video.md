# argument-video — making a video that argues something

A sibling of `demo-video.md`. That one records **an exhibit**: an app
exists, you drive it, you talk over it. This one makes a film where
**there is no app** — the picture is built to carry an argument, and the
argument is the deliverable.

Video 0 of the Polyglot series is the worked example throughout. Every
rule below was paid for.

## Which skill you want

| You have | Use |
|---|---|
| A running showcase to demonstrate | `demo-video.md` (Mode A) |
| A static page of output to walk through | `demo-video.md` (Mode B) |
| A case to make, and no software to show | **here** |

---

## The three passes

**1 · Measure the words. 2 · Build the picture to them. 3 · Fit the final
take to the picture.**

The VO-first principle from `demo-video.md` still holds — software is
patient, a voice is not — but it splits in two here, because the picture
does not exist yet. The first recording is not a take. It is an
**instrument**: its only job is to produce fifteen durations. The final
performance is recorded *last*, against the finished animation, and that
one is the master.

Do not let pass 1's audio become the master by accident. It will be
tempting — it will be a real read, it will sound fine, and it will have
been edited. It is a reference.

---

## Pass 1 · Measure the words

### Write it as a deck, not a script

Prose you read aloud comes out as prose read aloud. Bullets you speak
*from* come out as speech. So the source is a markdown deck — headline,
what's on screen, what to say — and `docs/tools/deck.py` serves it with
live reload:

```bash
python3 tools/deck.py kb/plans/polyglot-video-0-deck-v5.md --port 4183
```

```
# Section              a running label carried by following slides
## 7 · SLIDE TITLE     starts a slide
⟲ FLAG — note          a change badge on that slide
- bullet               what would be ON SCREEN
> speaker note         what to SAY
```

Keys: `← →` move · `g` overview · `h` hide notes · `r` arm the advance
log · `t` print it.

The speaker edits the markdown in one window and reloads the deck in
another. Six versions in a morning is normal and is the point.

### The deck is also a fit test

`deck.py` auto-shrinks a slide that overflows and shows a badge —
`TIGHT — CONSIDER SPLITTING` below 0.79, `OVERFULL — SPLIT THIS SLIDE`
below 0.6. This is not cosmetic. An overfull slide **cost a whole beat of
a take**: two slides didn't fit, the speaker said *"I'm going to skip
slides 17"* mid-flow, and the only first-hand evidence in the video went
with it. If the badge is on, the slide is wrong, not the screen.

### Getting the boundaries out — three attempts, one winner

The hard problem is knowing where beat N ended and beat N+1 began, from a
single continuous human performance. Three things were tried:

| Instrument | Result |
|---|---|
| **Spacebar cue mode** in the animation | Worked, but required the tab focused and coupled measurement to an artifact that was about to be thrown away |
| **Saying "next slide" aloud** | Forgotten. Once in take 1, nine times in take 2, abandoned by take 5. Anything the speaker must remember mid-sentence, they won't |
| **The deck logging its own advances** | ✅ Nothing asked of the speaker. Press `r`, perform, press `t`, paste the table |

**Make the tool that the speaker is already operating do the
measurement.** They are pressing → to advance anyway; that keypress is
the boundary. Every scheme that adds a second obligation fails, and it
fails silently — you find out when you transcribe.

```js
function stamp() {
  const at = Math.round(performance.now() - T0);
  const prev = LOG[LOG.length - 1];
  if (prev && prev.slide === i + 1) return;   // a re-render, not a move
  if (prev) prev.durMs = at - prev.atMs;
  LOG.push({ slide: i + 1, title: SLIDES[i].title, atMs: at });
}
```

Note the re-render guard: live reload re-renders constantly, and without
it every save writes a phantom zero-length beat.

### Do not try to recover boundaries from the audio

Silence detection was investigated properly and is **dead**. Zero pauses
found at every threshold from −20 dB to −55 dB, on takes with the room
fan both on and off (mean −35.7 vs −35.9 dB — no measurable difference).
The recorder's AGC lifts room tone into the gaps, so the gaps aren't
there. Don't spend the hour.

### Transcribe every take

The Whisper service on the MacMini, raw body — multipart fails with a
misleading ffmpeg banner:

```bash
curl -X POST -H "Content-Type: audio/mp4" --data-binary @take.m4a \
  http://andrews-mac-mini:3200/transcribe
```

Transcripts go in `kb/plans/takes/video-N-take-M.md` with a glossary of
what Whisper garbled, because it will consistently mangle the same
domain terms and you will re-derive them otherwise.

Read the transcript against the deck, not against your memory of the
take. The gap between them is the edit.

### What the transcripts are actually for

Two things, and only one is obvious.

**Structure.** The speaker rambling on a slide means the slide is wrong.
Six takes produced: a new opening slide (ad-libbed in take 1, promoted to
the deck), one slide deleted for being divisive, two slides split, one
slide's ending rewritten to land on a demand rather than a diagnosis, and
the final slide rewritten as six numbered beats because improvisation
kept dropping the one that carried the claim.

**Diagnosing length honestly.** Takes 1–5 all ran 137–144 wpm, so the
length was never delivery speed — it was word count. Take 6 hit 160 wpm,
meaning ~4% fewer words but 12% less time. That is a trade the speaker
made under pressure, not an improvement, and it should be reported as
one. Compute wpm per take; without it "it got shorter" is uninterpretable.

---

## Pass 2 · Build the picture

### Static composition first. Always.

**Do not open a timeline until the layout is right.** Composition
problems are compositional; debugging them through an animation is
slower by an order of magnitude and confuses "this reads badly" with
"this is mistimed".

The deliverable of this pass is one wide static surface — words, arrows,
shapes — plus the poster frame composed deliberately as its own artefact,
because the poster is the thumbnail.

### The durations are the layout constraint

Station width tracks narration time, so a constant-speed camera arrives
on time **by construction**. A 90-second beat needs enough on screen to
survive being looked at for 90 seconds; a 16-second beat must not be
over-furnished.

Two corrections to that, both learned the hard way:

**Fold the surface.** Fifteen beats in one line gives an aspect ratio no
pull-back can land on. Three boustrophedon passes fixed it — with the
rule that **turns land on events, never on travel**, so a fold never
happens mid-thought.

**Do not floor the station width.** Short beats crowding was a real
problem, and flooring each station at one frame-width was the wrong
fix — it inflated the surface to 4.44:1, marooned every short beat in
empty ground, and destroyed the pull-back. The right fix is to **decouple
revealing from travelling**: where the camera is static, elements fade or
defocus in, so two short adjacent beats share a frame and separate in
**time** instead of in space.

### Judge by camera frames, never the fit view

This is the single most important rule in the pass, and it hid real
problems on two consecutive rounds. Fit-to-width shows a handsome poster;
it cannot show you that four consecutive frames are the same picture, or
that a turn reads as a racetrack when you're inside it.

Build a headless exporter that forces the stage open — the study keeps
its surface inside a scroller, so an ordinary screenshot silently
captures only the visible width and comes back looking like a *rendering*
failure rather than a *clipping* one:

```
composition-export.html?fx=<x>&fy=<pass×1080>&s=1   one 1920×1080 frame
composition-export.html?s=0.5                       the whole surface
```

Generate all N frames and read them **in order, as a viewer would**.

### Make colour mean something, and count it

Give each runtime its own hue, introduced where they fan out and
recurring where they're compared. Then fix the counts and state them:
ochre exactly three times, five hues exactly three times each, solid
versus ringed terminals distinguishing production from series. A colour
system you can audit is a colour system; anything else is decoration.

### Answer a callback with a ghost, not a journey

An objection planted at beat 9 and answered at beat 15 must **not** be
solved by flying the camera home. It was tried: once intermediate marks
are on screen, it is impossible to tell *which* mark it returned to.
Bring a ghost or echo of the earlier mark forward into the later frame.
Same payoff, no disorientation.

### Briefing a designer across rounds

One file per round, each stating what is **kept** as explicitly as what
changes — an unqualified list of fixes reads as licence to redesign, and
you lose work that was right. Require the designer to **report the
station coordinates** in the hand-back; guessing them from the DOM makes
correct framing look broken.

When a round fails because of how you specified it, say so in the next
brief. "That instruction was wrong, here is why" gets a narrow correction;
silence gets another rethink.

---

## Pass 3 · Record against the picture

Now the animation exists and the timings are real, the final take is
performed to it. This is the master.

**Some things are cheaper to fix on screen than in the audio.** A
misspoken word became an on-screen asterisk and a footnote rather than a
punch-in. A recording session has diminishing returns and the speaker
knows where they are; when they say so, believe them.

**A pickup for the last beat is free.** The final beat lands on the final
frame with nothing after it to sync against, so it can always be
re-recorded and slotted in. Nothing else has that property.

---

## Kit notes

**A bad wired mic beats good AirPods.** As *input*, AirPods drop to a
Bluetooth voice profile — roughly half the bandwidth, with
non-defeatable noise reduction and AGC that you cannot get behind. If
you need to check what a file actually contains: a hard cliff at 16 kHz
is a codec artifact, and a gradual rolloff is the capsule. Only the
second is the microphone's fault.

**Locating a splice acoustically.** With no timestamps, binary-search
short excerpts through Whisper to pin an edit point to ±0.5 s. Do not
estimate it from word position in the transcript — that was 8 seconds
wrong. Validate the corrected model at *both* ends of the timeline
before trusting it.

## See also

- `demo-video.md` — recording an exhibit (Modes A and B)
- `docs/tools/deck.py` — the deck server and advance log
- `docs/kb/plans/polyglot-video-0-deck-v5.md` — a settled deck
- `docs/kb/plans/takes/` — transcripts and the measured beat sheet
- `docs/kb/plans/polyglot-video-0-composition-*.md` — the round briefs
