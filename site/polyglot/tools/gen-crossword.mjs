// Generate the interlocking-word crossword hero and inject it into the landing
// page (public/index.html), between the <!-- CWHERO:START/END --> markers.
//
//   npm run crossword
//
// We pack the grid OURSELVES (a greedy crossing packer) rather than using
// crossword-layout-generator, which ignores input order and sprawls past 15
// wide. Longest word first; each next word crosses an existing shared letter;
// candidates scored by resulting compactness. Reproducible (seeded). POLYGLOT
// is just another word, tinted red.  Add a backend → edit WORDS → re-run.

import { writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC = join(__dirname, '..', 'public');

// answer → { backend page, accent, label }. POLYGLOT = the brand (red).
// PALETTE = 'official' uses each language's real brand colour (sampled from its
// logo/site); 'curated' uses a hand-picked harmonious set. Toggle to compare.
const PALETTE = process.env.PALETTE || 'curated';

// Official brand colours, sampled from each language's logo / brand guide.
// CHEZ (Scheme) has no official brand colour — flagged with a neutral slate.
const OFFICIAL = {
  POLYGLOT: '#c23b22',  // ours (brand red)
  PURESCRIPT: '#1d222d', // PureScript logo dark slate
  ERLANG: '#a90533',     // Erlang red
  JULIA: '#9558b2',      // Julia purple (one of the four official dots)
  PYTHON: '#3776ab',     // Python blue
  RACKET: '#9f1d35',     // Racket red
  WASM: '#654ff0',       // WebAssembly purple
  CHEZ: '#5b6770',       // Scheme/Chez — NO official brand; neutral slate
  NODE: '#5fa04e',       // Node.js green (2022 logo)
  LUA: '#000080',        // Lua navy
  GO: '#00add8',         // Go cyan (gopher blue)
};

// A harmonious, well-separated set for the light theme. Keeps POLYGLOT's brand
// red + PureScript ink as anchors and echoes a few brands (Go teal, Node green,
// Python blue); brand-less Chez gets a neutral grey. Hues spread across the
// wheel so no two words read as the same colour.
const CURATED = {
  POLYGLOT: '#c0392b',   // brand red
  PURESCRIPT: '#1d222d', // ink — the through-line
  ERLANG: '#ef8a3b',     // orange
  JULIA: '#b07aa1',      // mauve
  PYTHON: '#4e79a7',     // blue (echoes Python)
  RACKET: '#d4569b',     // magenta
  WASM: '#5b4fd6',       // indigo
  CHEZ: '#8d8d8d',       // neutral grey (no brand)
  NODE: '#59a14f',       // green (echoes Node)
  LUA: '#e3b505',        // gold
  GO: '#29b3c0',         // teal (echoes Go)
};

const PAL = PALETTE === 'curated' ? CURATED : OFFICIAL;
const A = (w) => PAL[w];

// label = the runtime's USE CASE — a positive claim for why you'd target it.
// Sourced from each backend's "native niche" in docs/backends/backend-comparison.md.
const WORDS = [
  { answer: 'POLYGLOT',   backend: null,      accent: A('POLYGLOT'),   href: 'index.html#backends', label: 'one type system' },
  { answer: 'PURESCRIPT', backend: 'js',      accent: A('PURESCRIPT'), href: 'backends/js/',      label: 'types, everywhere' },
  { answer: 'ERLANG',     backend: 'purerl',  accent: A('ERLANG'),     href: 'backends/purerl/',  label: 'fault-tolerant systems' },
  { answer: 'JULIA',      backend: 'jurist',  accent: A('JULIA'),      href: 'backends/jurist/',  label: 'scientific computing' },
  { answer: 'PYTHON',     backend: 'purepy',  accent: A('PYTHON'),     href: 'backends/purepy/',  label: 'data science & ML' },
  { answer: 'RACKET',     backend: 'purkt',   accent: A('RACKET'),     href: 'backends/purkt/',   label: 'languages & DSLs' },
  { answer: 'WASM',       backend: 'wasm',    accent: A('WASM'),       href: 'backends/wasm/',    label: 'high-performance compute' },
  { answer: 'CHEZ',       backend: 'purescm', accent: A('CHEZ'),       href: 'backends/purescm/', label: 'Lisp metaprogramming' },
  { answer: 'NODE',       backend: 'js',      accent: A('NODE'),       href: 'backends/js/',      label: 'web apps & APIs' },
  { answer: 'LUA',        backend: 'lua',     accent: A('LUA'),        href: 'backends/lua/',     label: 'embedded scripting' },
  { answer: 'GO',         backend: 'psgo',    accent: A('GO'),         href: 'backends/psgo/',    label: 'cloud services & CLIs' },
];

const POINTS = { A:1,B:3,C:3,D:2,E:1,F:4,G:2,H:4,I:1,J:8,K:5,L:1,M:3,N:1,O:1,P:3,Q:10,R:1,S:1,T:1,U:1,V:4,W:4,X:8,Y:4,Z:10 };
const idxOf = (answer) => WORDS.findIndex((w) => w.answer === answer);

function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
function shuffled(arr, rng){const a=arr.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}

// ---- our greedy crossing packer ----
function pack(order){
  const grid = new Map();      // "x,y" -> char
  const owners = new Map();    // "x,y" -> Set(wordIndex)
  const placements = [];
  const K = (x,y)=>x+','+y;
  let minx=0,maxx=0,miny=0,maxy=0;

  function fits(word,x,y,dir){
    let crossings=0;
    for(let i=0;i<word.length;i++){
      const cx=dir==='H'?x+i:x, cy=dir==='V'?y+i:y, ex=grid.get(K(cx,cy));
      if(ex!==undefined){ if(ex!==word[i]) return -1; crossings++; }
      else if(dir==='H'){ if(grid.has(K(cx,cy-1))||grid.has(K(cx,cy+1))) return -1; }
      else { if(grid.has(K(cx-1,cy))||grid.has(K(cx+1,cy))) return -1; }
    }
    if(dir==='H'){ if(grid.has(K(x-1,y))||grid.has(K(x+word.length,y))) return -1; }
    else { if(grid.has(K(x,y-1))||grid.has(K(x,y+word.length))) return -1; }
    return crossings;
  }
  function put(word,wi,x,y,dir){
    for(let i=0;i<word.length;i++){const cx=dir==='H'?x+i:x,cy=dir==='V'?y+i:y,k=K(cx,cy);
      grid.set(k,word[i]); if(!owners.has(k))owners.set(k,new Set()); owners.get(k).add(wi);
      minx=Math.min(minx,cx);maxx=Math.max(maxx,cx);miny=Math.min(miny,cy);maxy=Math.max(maxy,cy);}
    placements.push({wi,answer:word,x,y,dir});
  }

  put(order[0].answer, order[0].wi, 0, 0, 'H');
  let unplaced=0;
  for(let n=1;n<order.length;n++){
    const {answer:word, wi}=order[n];
    let best=null;
    for(const [k,pc] of grid){
      const [px,py]=k.split(',').map(Number);
      for(let i=0;i<word.length;i++){
        if(word[i]!==pc) continue;
        for(const dir of ['H','V']){
          const x=dir==='H'?px-i:px, y=dir==='V'?py-i:py;
          if(fits(word,x,y,dir)<1) continue;
          const ex2=dir==='H'?x+word.length-1:x, ey2=dir==='V'?y+word.length-1:y;
          const w=Math.max(maxx,ex2)-Math.min(minx,x)+1, h=Math.max(maxy,ey2)-Math.min(miny,y)+1;
          const area=w*h, span=Math.max(w,h);                    // prefer compact + square-ish
          if(!best || area<best.area || (area===best.area && span<best.span)){ best={x,y,dir,area,span}; }
        }
      }
    }
    if(best) put(word,wi,best.x,best.y,best.dir); else { placements.push({wi,answer:word,unplaced:true}); unplaced++; }
  }
  return {grid,owners,placements,minx,maxx,miny,maxy,unplaced};
}

// Try many word orders (longest-first bias + seeded shuffles), keep the tightest
// all-placed result that fits 15×15.
function bestPacking(){
  const rng=mulberry32(0x50DA);
  const base=WORDS.map((w,i)=>({answer:w.answer,wi:i})).sort((a,b)=>b.answer.length-a.answer.length);
  let best=null;
  for(let t=0;t<4000;t++){
    const order = t===0 ? base : [base[0], ...shuffled(base.slice(1),rng)];   // keep longest anchor
    const p=pack(order);
    if(p.unplaced) continue;
    const cols=p.maxx-p.minx+1, rows=p.maxy-p.miny+1;
    const fits=cols<=15 && rows<=15;
    let crossings=0; for(const s of p.owners.values()) if(s.size>1) crossings++;
    const score=(fits?0:1e6)+cols*rows*10-crossings;
    if(!best||score<best.score) best={p,cols,rows,fits,crossings,score};
  }
  return best;
}

// Normalise to a 1-indexed cells map + legend result.
function normalise(b){
  const {p}=b;
  const cells=new Map();
  for(const [k,ch] of p.grid){const [x,y]=k.split(',').map(Number);
    cells.set(`${x-p.minx+1},${y-p.miny+1}`,{ch,words:p.owners.get(k)});}
  const result=p.placements.filter(q=>!q.unplaced).map(q=>({answer:q.answer,
    startx:q.x-p.minx+1, starty:q.y-p.miny+1, orientation:q.dir==='H'?'across':'down'}));
  return { cols:b.cols, rows:b.rows, cells, result };
}

const accentMap = JSON.stringify(Object.fromEntries(WORDS.map((w,i)=>[i,w.accent])));

// The legend lists the "other languages" — POLYGLOT (the family) and PURESCRIPT
// (the source) stay on the board but are not legend entries.
const LEGEND_SKIP = new Set(['POLYGLOT', 'PURESCRIPT']);
function legendHtml(L, pre){
  return L.result.slice().filter(r=>!LEGEND_SKIP.has(r.answer)).sort((a,b)=>idxOf(a.answer)-idxOf(b.answer)).map(r=>{
    const wi=idxOf(r.answer),w=WORDS[wi],pts=[...w.answer].reduce((s,ch)=>s+(POINTS[ch]||0),0);
    return `<a class="leg" href="${pre}${w.href}" data-word="${wi}" style="--accent:${w.accent}">
      <span class="leg__sw"></span><span class="leg__word">${w.answer}</span>
      <span class="leg__label">${w.label}</span><span class="leg__pts">${pts}</span></a>`;
  }).join('\n');
}

const LEGEND_CSS = `
.side{display:grid;gap:.8rem;}
.side__kicker{font-size:.72rem;text-transform:uppercase;letter-spacing:.18em;color:var(--ink-faint);font-weight:700;margin:0;}
.side__title{font-family:var(--display);font-weight:700;font-size:clamp(1.3rem,3vw,1.9rem);line-height:1.12;margin:0 0 .55rem;}
/* handwritten kicker under the headline — a gently tilted aside, not a strike.
   Upright hand (Patrick Hand) so it doesn't read as italic; rotation on the
   whole inline-block element, tunable via --hand-rot. */
.side__hand{display:inline-block;position:relative;z-index:2;font-family:'Patrick Hand','Bradley Hand',cursive;color:var(--primary);font-size:clamp(1.45rem,3.4vw,2.1rem);line-height:1;margin:var(--hand-rise,-0.8em) 0 1.4rem var(--hand-shift,2rem);transform:rotate(var(--hand-rot,-5deg));transform-origin:left center;}
.legend{display:grid;gap:.05rem;}
.leg{display:grid;grid-template-columns:.7rem 1fr auto;column-gap:.6rem;row-gap:0;padding:.3rem .4rem;border-radius:5px;color:var(--ink);align-items:center;}
.leg:hover,.leg.active{text-decoration:none;background:var(--paper-2);}
.leg__sw{grid-row:1/3;width:.7rem;height:.7rem;border-radius:2px;background:var(--accent);}
.leg__word{grid-column:2;grid-row:1;font-family:var(--display);font-weight:700;text-transform:uppercase;letter-spacing:.03em;font-size:.82rem;color:var(--ink-faint);}
.leg__label{grid-column:2;grid-row:2;font-size:.98rem;font-weight:600;color:var(--ink);line-height:1.15;}
.leg__pts{grid-column:3;grid-row:1/3;align-self:center;font-size:.72rem;color:var(--ink-faint);font-variant-numeric:tabular-nums;}
.leg.active .leg__word{color:var(--accent);}
.leg.active .leg__label{color:var(--accent);}`;

// Headline is the purescript.org line, left whole. A gently-tilted handwritten
// kicker underneath reframes it (no strike-through). The Patrick Hand webfont is
// linked from index.html's <head>.
const SIDE = (L,pre)=>`<div class="side">
<h1 class="side__title">A strongly-typed functional programming language that compiles to JavaScript</h1>
<p class="side__hand">&amp; all these other languages, too</p>
<div class="legend" id="legend">${legendHtml(L,pre)}</div></div>`;

const SYNC_JS = (sel)=>`
  const ACCENT=${accentMap};const board=document.getElementById('board'),legend=document.getElementById('legend');
  const cf=id=>board.querySelectorAll('${sel}[data-words~="'+id+'"]'),lf=id=>legend.querySelector('.leg[data-word="'+id+'"]');
  function on(id){const a=ACCENT[id];cf(id).forEach(c=>{c.style.setProperty('--hl',a);c.classList.add('hl');});const l=lf(id);if(l)l.classList.add('active');}
  function off(id){cf(id).forEach(c=>c.classList.remove('hl'));const l=lf(id);if(l)l.classList.remove('active');}
  legend.querySelectorAll('.leg').forEach(l=>{const id=l.dataset.word;l.onmouseenter=()=>on(id);l.onmouseleave=()=>off(id);});
  board.querySelectorAll('${sel}[data-words]').forEach(c=>{const ids=c.dataset.words.split(' ');c.onmouseenter=()=>ids.forEach(on);c.onmouseleave=()=>ids.forEach(off);});`;

function boardCells(L){
  let grid='';
  for(let y=1;y<=L.rows;y++) for(let x=1;x<=L.cols;x++){
    const c=L.cells.get(`${x},${y}`);
    if(!c){grid+=`<span class="cell cell--blank"></span>`;continue;}
    let cls='cell';
    if(c.words.has(idxOf('POLYGLOT'))) cls+=' cell--brand';
    if(c.words.has(idxOf('PURESCRIPT'))) cls+=' cell--pure';
    grid+=`<span class="${cls}" data-words="${[...c.words].join(' ')}">${c.ch}</span>`;
  }
  return grid;
}

// The landing hero: a self-contained <style>+markup+<script> block injected into
// public/index.html between the CWHERO markers. Class names are unique to the
// crossword (board/cell/side/leg/…); only the container is renamed (.cwhero/
// .cw-wrap) so it can't collide with the page's own .hero/.wrap.
function renderLandingHero(L){
  return `<style>
.cwhero-shell{position:relative;}
.cwhero{min-height:100vh;display:grid;place-items:center;padding:6rem var(--space) 4rem;background:radial-gradient(120% 80% at 80% 0%,var(--paper-2),var(--paper) 60%);}
.cw-wrap{display:grid;grid-template-columns:auto minmax(12rem,20rem);gap:clamp(2.5rem,5vw,5rem);align-items:center;}
.board{display:grid;grid-template-columns:repeat(${L.cols},clamp(24px,2.9vw,42px));gap:2px;}
.cell{aspect-ratio:1;display:grid;place-items:center;font-family:var(--display);font-weight:700;text-transform:uppercase;font-size:clamp(.85rem,1.9vw,1.55rem);color:var(--ink);background:var(--paper);border:1px solid var(--line);border-radius:2px;transition:.12s;}
.cell--blank{background:transparent;border:none;}
.cell--brand{color:var(--primary);border-color:rgba(194,59,34,.4);}
.cell.hl{color:#fff;background:var(--hl,var(--ink));border-color:transparent;transform:scale(1.05);}
.board:not(:has(.cell.hl)) .cell--pure{background:var(--ink);color:#fff;border-color:var(--ink);}
${LEGEND_CSS}
@media(max-width:820px){.cw-wrap{grid-template-columns:1fr;}.board{order:2;}}
</style>
<div class="cwhero"><div class="cw-wrap"><div class="board" id="board">${boardCells(L)}</div>${SIDE(L,'')}</div></div>
<script>${SYNC_JS('.cell')}</script>`;
}

// ---- run ----
const b = bestPacking();
if(!b){ console.error('No all-placed packing found.'); process.exit(1); }
const L = normalise(b);

// Inject the crossword hero into the landing between the CWHERO markers.
// PALETTE selects the colour set (default 'curated').
{
  const idxPath=join(PUBLIC,'index.html');
  const S='<!-- CWHERO:START -->', E='<!-- CWHERO:END -->';
  let idx=readFileSync(idxPath,'utf8');
  const i=idx.indexOf(S), j=idx.indexOf(E);
  if(i!==-1 && j!==-1 && j>i){
    idx = idx.slice(0,i+S.length) + '\n' + renderLandingHero(L) + '\n  ' + idx.slice(j);
    writeFileSync(idxPath, idx);
    console.log('Injected crossword hero into public/index.html');
  } else {
    console.log('NOTE: CWHERO markers not found in public/index.html — landing hero NOT updated.');
  }
}

// ASCII preview
let preview='';
for(let y=1;y<=L.rows;y++){let row='';for(let x=1;x<=L.cols;x++){const c=L.cells.get(`${x},${y}`);row+=c?c.ch:'·';}preview+=row+'\n';}
console.log(`Best packing: ${L.cols}×${L.rows}, ${b.crossings} crossings, fits-board=${b.fits}`);
const unplaced=b.p.placements.filter(q=>q.unplaced).map(q=>q.answer);
if(unplaced.length) console.log('UNPLACED:', unplaced.join(', '));
console.log('');
console.log(preview);
