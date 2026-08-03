/* ============================================================================
   SCROLL DRIVER — Mode B (static page, no service, no app state)
   ----------------------------------------------------------------------------
   The sibling of demo-video-capture-driver.js. That one drives an APP: tabs,
   buttons, readouts, state to guard on. This one drives a PAGE: there is no
   application, nothing to click, and no state to wait for — the only verb is
   "put this on screen and hold while I talk about it."

   That difference is why Mode B is cheap. No server, no seed, no master-state
   URL beyond the file itself; a page that renders identically every time is a
   page you can re-record a beat of tomorrow without reconstructing anything.

   Usage — identical to the capture driver, deliberately:
     1. Serve the page (see the recipe in demo-video.md; file:// also works if
        the page has no fetch()).
     2. Paste this whole file into the browser console.
     3. Rehearse:  DEMO.speed = 4; DEMO.play()
     4. Close the console, press 0, start recording.

   VO-FIRST: BEATS[] is the only thing you retime. Each `hold` is the measured
   duration of that VO segment in milliseconds. Never sprinkle timing constants
   through the body.
   ========================================================================== */
window.DEMO = (() => {

  // ---- 1 · the beats — the only per-page part ------------------------------
  //
  // `at` accepts three forms, and you will use all of them:
  //   'selector'          — first match. Best when the page has a real id.
  //   { sel: '.act', n:2 } — the nth match, 1-based. Use when a page repeats a
  //                          structural class instead of naming each section.
  //                          Needs no edit to the page, which matters: these
  //                          pages' ids (#act2, #act3) are DATA MOUNT POINTS
  //                          the page's own JS writes into, not anchors — take
  //                          one for a heading anchor and you break the page.
  //   0.0 … 1.0           — fraction of total scroll height. Always resolves,
  //                          but drifts as soon as the content changes length.
  //
  // `hold` is milliseconds measured from the recorded VO segment.
  // `align` is passed to scrollIntoView's `block` (start | center | end).
  //
  // Below: the real beats for dimensions-viz, as a worked example.

  const BEATS = [
    { at: 'h1',                  hold: 12000, align: 'start' }, // B1 — title, thesis
    { at: { sel: '.act', n: 1 }, hold: 18000, align: 'start' }, // B2 — types do the algebra
    { at: { sel: '.act', n: 2 }, hold: 22000, align: 'start' }, // B3
    { at: { sel: '.act', n: 3 }, hold: 20000, align: 'start' }, // B4
    { at: { sel: '.act', n: 4 }, hold: 20000, align: 'start' }, // B5 — the payoff
    { at: 1.0,                   hold:  9000, align: 'end'   }, // B6 — silent end-card
  ];

  // ---- 2 · global timing ---------------------------------------------------
  const T = {
    settle:      1200,   // after load, before the first move — let fonts land
    scrollMs:     900,   // duration of each glide; honoured exactly (see below)
    afterScroll:  400,   // beat of stillness once arrived, before the VO line
    headroom:      48,   // px above a 'start'-aligned element, so it isn't
                         // welded to the top edge of frame
  };

  let speed = 1;
  const sleep = ms => new Promise(r => setTimeout(r, ms / speed));

  // ---- why we animate the scroll ourselves ---------------------------------
  //
  // We do NOT use `behavior: 'smooth'`. Measured 2026-08-03 in the capture
  // context: BOTH `el.scrollIntoView({behavior:'smooth'})` and
  // `window.scrollTo({top, behavior:'smooth'})` are silent no-ops — the page
  // stays at scrollY 0 — while the identical calls with `behavior:'auto'`
  // land exactly on target. No error, no warning. That is the worst failure
  // mode available to a capture driver: it looks like it ran, and you find
  // out the page never moved while you are recording.
  //
  // Animating with rAF also fixes something the browser could never give us:
  // `behavior:'smooth'` takes however long Chrome decides, whereas VO-first
  // timing needs a duration we CHOSE. Here T.scrollMs is honoured exactly.
  // We also do NOT drive the animation with requestAnimationFrame alone.
  // rAF does not fire in a hidden tab — measured the same day:
  // visibilityState 'hidden' => zero callbacks in 600 ms. A rAF-only glide
  // therefore HANGS FOREVER rather than failing, so a driver started before
  // the tab is frontmost, or covered by the recorder's own window, produces a
  // frozen take with no diagnostic. Stepping from a timer degrades (throttled
  // in the background) instead of deadlocking. In a visible foreground tab —
  // the only state you ever record in — timers are not throttled and a ~16 ms
  // step is indistinguishable from rAF.
  const easeInOutCubic = t => t < 0.5 ? 4*t*t*t : 1 - Math.pow(-2*t + 2, 3) / 2;

  const glideTo = top => new Promise(resolve => {
    const from = window.scrollY;
    const dist = top - from;
    const dur = Math.max(1, T.scrollMs / speed);
    if (Math.abs(dist) < 2) { window.scrollTo({ top, behavior: 'auto' }); return resolve(); }
    const t0 = performance.now();
    const step = () => {
      const t = Math.min(1, (performance.now() - t0) / dur);
      window.scrollTo({ top: from + dist * easeInOutCubic(t), behavior: 'auto' });
      if (t < 1) setTimeout(step, 16); else resolve();
    };
    step();
  });

  const maxScroll = () =>
    Math.max(0, document.documentElement.scrollHeight - window.innerHeight);

  // Resolve any of the three `at` forms to an element, or null for fractions.
  const resolve = at => {
    if (typeof at === 'number') return null;
    if (typeof at === 'string') return document.querySelector(at);
    return document.querySelectorAll(at.sel)[(at.n || 1) - 1] || null;
  };
  const describe = at =>
    typeof at === 'number' ? `${at} (fraction)`
      : typeof at === 'string' ? at
      : `${at.sel} [${at.n || 1}]`;

  // Where a beat wants the viewport to sit, in absolute page coordinates.
  const topFor = (at, align) => {
    if (typeof at === 'number') return maxScroll() * at;
    const el = resolve(at);
    if (!el) return null;
    const r = el.getBoundingClientRect();
    const absTop = r.top + window.scrollY;
    if (align === 'center') return absTop - (window.innerHeight - r.height) / 2;
    if (align === 'end')    return absTop + r.height - window.innerHeight;
    return absTop - T.headroom;                       // 'start', with breathing room
  };

  const goto = async (at, align) => {
    const top = topFor(at, align);
    if (top === null) { console.warn(`[DEMO] no element for ${describe(at)} — beat skipped`); return false; }
    await glideTo(Math.max(0, Math.min(maxScroll(), top)));
    return true;
  };

  const play = async () => {
    window.scrollTo({ top: 0, behavior: 'auto' });
    await sleep(T.settle);
    for (let i = 0; i < BEATS.length; i++) {
      const b = BEATS[i];
      console.log(`[DEMO] B${i + 1} → ${describe(b.at)}`);
      await goto(b.at, b.align);
      await sleep(T.afterScroll);
      await sleep(b.hold);
    }
    console.log('[DEMO] done');
  };

  // A dry run that reports what the beats WOULD hit, without moving anything.
  // Run this before the first rehearsal: a typo'd selector is otherwise a
  // silent no-op that you discover mid-take.
  const check = () => {
    let ok = true;
    if (document.visibilityState !== 'visible') {
      console.warn('[DEMO] this tab is HIDDEN — bring it frontmost before recording.');
    }
    if (maxScroll() === 0) {
      ok = false;
      console.error('[DEMO] page does not scroll — every beat would be a no-op.');
    }
    BEATS.forEach((b, i) => {
      const d = describe(b.at);
      if (typeof b.at === 'number') { console.log(`B${i + 1}  ${d} — always resolves`); return; }
      const el = resolve(b.at);
      if (!el) { ok = false; console.error(`B${i + 1}  ${d} — NOT FOUND`); }
      else console.log(`B${i + 1}  ${d} — ok: "${(el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 60)}"`);
    });
    // Two beats that resolve to the same scroll position are two VO segments
    // over one unchanging shot — the viewer sees a freeze. Usually it means
    // the page is shorter than the beat sheet assumes at this viewport
    // height, so the last beats clamp to the bottom and collapse together.
    // Fix by merging the beats, or by recording at a smaller viewport.
    const tops = BEATS.map(b => {
      const t = topFor(b.at, b.align);
      return t === null ? null : Math.round(Math.max(0, Math.min(maxScroll(), t)));
    });
    tops.forEach((t, i) => {
      if (t !== null && i > 0 && t === tops[i - 1]) {
        console.warn(`[DEMO] B${i} and B${i + 1} both land at ${t}px — same shot, ` +
                     `no visible change. Merge them or record at a shorter viewport.`);
      }
    });
    console.log('targets:', tops.map((t, i) => `B${i + 1}:${t}`).join('  '),
                `(max ${Math.round(maxScroll())})`);

    const total = BEATS.reduce((n, b) => n + b.hold, 0) + T.settle
                + BEATS.length * (T.scrollMs + T.afterScroll);
    console.log(`total run: ${(total / 1000).toFixed(1)}s`);
    return ok;
  };

  return {
    play, check, BEATS, T,
    get speed() { return speed; },
    set speed(v) { speed = v; },
  };
})();

window.addEventListener('keydown', e => {
  if (e.key === '0') { e.preventDefault(); DEMO.play(); }
});

console.log('DEMO ready — DEMO.check() first, then press 0 to play. DEMO.speed=4 to rehearse.');
