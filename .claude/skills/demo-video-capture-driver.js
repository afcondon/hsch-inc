/* ============================================================================
   CAPTURE DRIVER — template
   ----------------------------------------------------------------------------
   Drives a showcase deterministically through its beat sheet so the screen
   recording is one clean pass. Generalised from kibitzer/video/capture-driver.js.

   Usage
     1. Serve the app at its master-state URL (seed/params fixed).
     2. Paste this whole file into the browser console.
     3. Rehearse:  DEMO.speed = 2; DEMO.play()
     4. Close the console, press 0, start recording.

   VO-FIRST: the T{} block is the ONLY thing you retime. Set each entry from
   the measured duration of its VO segment. Never sprinkle timing constants
   through the body — if you find yourself wanting to, add a T entry instead.

   Two things to fill in: the SELECTORS map and the T block. Then write play().
   ========================================================================== */
window.DEMO = (() => {

  // ---- 1 · selector map — the only genuinely per-app part -------------------
  const SELECTORS = {
    tabs:    'nav.tabs button.tab',        // top-level navigation
    buttons: '.controls-float button',     // transport / stepper controls
    readout: '.controls-float',            // element whose text reports position
    iframe:  null,                         // e.g. 'iframe.worlds-frame', or null
  };

  // Named indices into the buttons list — read them off the live DOM once and
  // write them down, so the beats below say press('forward') not press(3).
  const B = { play: 1, back: 2, forward: 3, start: 6, end: 7 };

  // Regex that extracts a position from the readout, for state-based guards.
  const POS_RE = /E?\d+ ?\/ ?E\d+|— ?\/ ?E\d+/;

  // ---- 2 · retime these to the VO (milliseconds) ---------------------------
  const T = {
    holdAfterCut: 1000,   // let a page settle after a cut, before narration
    b1:          30000,   // one entry per beat, from the measured VO segment
    b2:          20000,
    stepPace:      300,   // brisk pace through the middle
    slowPace:      900,   // slow down into the payoff
    slowFrom:       95,   // position at which to drop to slowPace
    payoffHold:  20000,   // hold on the result — the viewer needs this
    outroHold:    9000,   // silent end-card
  };

  // ---- plumbing (rarely needs editing) -------------------------------------
  let speed = 1;
  const sleep = ms => new Promise(r => setTimeout(r, ms * speed));

  const tabs  = () => [...document.querySelectorAll(SELECTORS.tabs)];
  const btns  = () => [...document.querySelectorAll(SELECTORS.buttons)];
  const goTab = i => { tabs()[i]?.click(); };
  const press = k => { btns()[B[k]]?.click(); };

  // Read state rather than counting clicks — clicks get swallowed, state doesn't lie.
  const posText = () =>
    (document.querySelector(SELECTORS.readout)?.textContent.match(POS_RE) || [''])[0];

  // Step until the readout matches, ALWAYS with a hard cap. An unguarded loop
  // that hangs mid-capture costs you the take and the narration sync with it.
  async function stepUntil(pred, key = 'forward', pace = T.stepPace, max = 200) {
    for (let i = 0; i < max; i++) {
      if (pred(posText())) return true;
      press(key);
      await sleep(pace);
    }
    console.warn('[DEMO] stepUntil hit its cap — check the predicate');
    return false;
  }

  // Same-origin iframe helpers (null-safe when SELECTORS.iframe is null).
  const idoc  = () => document.querySelector(SELECTORS.iframe)?.contentDocument;
  const iclick = id => idoc()?.getElementById(id)?.click();
  async function waitIframe(id, tries = 60) {
    for (let i = 0; i < tries; i++) {
      if (idoc()?.getElementById(id)) return true;
      await sleep(100);
    }
    console.warn('[DEMO] iframe never became ready');
    return false;
  }

  async function reset() {
    location.hash = '';
    goTab(0);
    await sleep(200);
    press('start');
    await sleep(400);
  }

  // ---- 3 · the beats -------------------------------------------------------
  async function play() {
    console.log('[DEMO] start');
    await reset();

    // B1–B2 — frame the piece, held on the opening state
    await sleep(T.holdAfterCut);
    await sleep(T.b1 + T.b2);

    // B3 — brisk through the middle, then slow into the payoff
    await stepUntil(p => parseInt(p) >= T.slowFrom, 'forward', T.stepPace);
    await stepUntil(p => /^—/.test(p), 'forward', T.slowPace, 40);

    // B4 — hold on the result. Do not rush this.
    await sleep(T.payoffHold);

    // …further beats: goTab(n), sleep(T.holdAfterCut), drive, sleep(T.bn)…

    // Silent end-card
    goTab(tabs().length - 1);
    await sleep(T.holdAfterCut);
    await sleep(T.outroHold);

    console.log('[DEMO] done');
  }

  return {
    play, reset, goTab, press, posText, stepUntil, iclick, waitIframe, T,
    get speed() { return speed; },
    set speed(v) { speed = v; },
  };
})();

// Press "0" to start — lets you record with the console closed (no UI in frame).
window.addEventListener('keydown', e => {
  if (e.key === '0') { e.preventDefault(); DEMO.play(); }
}, true);

console.log('DEMO ready — press 0 to play (or DEMO.play()). DEMO.speed=2 to rehearse.');
