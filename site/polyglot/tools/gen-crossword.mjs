// Generate the interlocking-word hero(s) for the polyglot landing.
//
//   npm run crossword
//
// Emits two static, self-contained prototypes from the SAME packed layout:
//   public/crossword/index.html   — clean criss-cross hero
//   public/scrabble/index.html    — Scrabble-board knockoff (15×15, premiums,
//                                    tile point values)
//
// We pack the grid OURSELVES (a greedy crossing packer) rather than using
// crossword-layout-generator, which ignores input order and sprawls past 15
// wide. Longest word first; each next word crosses an existing shared letter;
// candidates scored by resulting compactness. Reproducible (seeded). POLYGLOT
// is just another word, tinted red.  Add a backend → edit WORDS → re-run.

import { writeFileSync, mkdirSync } from 'node:fs';
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

// Standard Scrabble premium grid. 3=TW 2=DW t=TL d=DL *=center .=plain.
const PREMIUM = [
  '3..d...3...d..3', '.2...t...t...2.', '..2...d.d...2..', 'd..2...d...2..d',
  '....2.....2....', '.t...t...t...t.', '..d...d.d...d..', '3..d...*...d..3',
  '..d...d.d...d..', '.t...t...t...t.', '....2.....2....', 'd..2...d...2..d',
  '..2...d.d...2..', '.2...t...t...2.', '3..d...3...d..3',
];

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

function legendHtml(L, pre){
  return L.result.slice().sort((a,b)=>idxOf(a.answer)-idxOf(b.answer)).map(r=>{
    const wi=idxOf(r.answer),w=WORDS[wi],pts=[...w.answer].reduce((s,ch)=>s+(POINTS[ch]||0),0);
    return `<a class="leg" href="${pre}${w.href}" data-word="${wi}" style="--accent:${w.accent}">
      <span class="leg__sw"></span><span class="leg__word">${w.answer}</span>
      <span class="leg__label">${w.label}</span><span class="leg__pts">${pts}</span></a>`;
  }).join('\n');
}

const LEGEND_CSS = `
.side{display:grid;gap:.8rem;}
.side__kicker{font-size:.72rem;text-transform:uppercase;letter-spacing:.18em;color:var(--ink-faint);font-weight:700;margin:0;}
.side__title{font-family:var(--display);font-weight:700;font-size:clamp(1.3rem,3vw,1.9rem);line-height:1.12;margin:0 0 .35rem;}
.side__title em{color:var(--primary);font-style:normal;}
.side__title s{color:var(--ink-faint);text-decoration-line:line-through;text-decoration-color:var(--primary);text-decoration-thickness:3px;}
.side__sub{font-family:var(--display);font-weight:600;font-size:clamp(1rem,2.2vw,1.35rem);line-height:1.2;color:var(--ink);margin:0 0 1.1rem;}
.side__sub em{color:var(--primary);font-style:normal;}
.legend{display:grid;gap:.05rem;}
.leg{display:grid;grid-template-columns:.7rem 1fr auto;column-gap:.6rem;row-gap:0;padding:.3rem .4rem;border-radius:5px;color:var(--ink);align-items:center;}
.leg:hover,.leg.active{text-decoration:none;background:var(--paper-2);}
.leg__sw{grid-row:1/3;width:.7rem;height:.7rem;border-radius:2px;background:var(--accent);}
.leg__word{grid-column:2;grid-row:1;font-family:var(--display);font-weight:700;text-transform:uppercase;letter-spacing:.03em;font-size:.82rem;color:var(--ink-faint);}
.leg__label{grid-column:2;grid-row:2;font-size:.98rem;font-weight:600;color:var(--ink);line-height:1.15;}
.leg__pts{grid-column:3;grid-row:1/3;align-self:center;font-size:.72rem;color:var(--ink-faint);font-variant-numeric:tabular-nums;}
.leg.active .leg__word{color:var(--accent);}
.leg.active .leg__label{color:var(--accent);}`;

// Headline riffs on purescript.org ("…that compiles to JavaScript") — strike the
// last clause, correct it with the subhead pointing at the board.
const HEADLINE = 'A strongly-typed functional programming language that <s>compiles to JavaScript</s>';
const SUBHEAD  = 'compiles &amp; interoperates with <em>all these</em> languages and runtimes.';

const SIDE = (L,pre)=>`<div class="side"><p class="side__kicker">One language, many runtimes</p>
<h1 class="side__title">${HEADLINE}</h1><p class="side__sub">${SUBHEAD}</p>
<div class="legend" id="legend">${legendHtml(L,pre)}</div></div>`;

const SYNC_JS = (sel)=>`
  const ACCENT=${accentMap};const board=document.getElementById('board'),legend=document.getElementById('legend');
  const cf=id=>board.querySelectorAll('${sel}[data-words~="'+id+'"]'),lf=id=>legend.querySelector('.leg[data-word="'+id+'"]');
  function on(id){const a=ACCENT[id];cf(id).forEach(c=>{c.style.setProperty('--hl',a);c.classList.add('hl');});const l=lf(id);if(l)l.classList.add('active');}
  function off(id){cf(id).forEach(c=>c.classList.remove('hl'));const l=lf(id);if(l)l.classList.remove('active');}
  legend.querySelectorAll('.leg').forEach(l=>{const id=l.dataset.word;l.onmouseenter=()=>on(id);l.onmouseleave=()=>off(id);});
  board.querySelectorAll('${sel}[data-words]').forEach(c=>{const ids=c.dataset.words.split(' ');c.onmouseenter=()=>ids.forEach(on);c.onmouseleave=()=>ids.forEach(off);});`;

function renderCrossword(L){
  let grid='';
  for(let y=1;y<=L.rows;y++) for(let x=1;x<=L.cols;x++){
    const c=L.cells.get(`${x},${y}`);
    if(!c){grid+=`<span class="cell cell--blank"></span>`;continue;}
    let cls='cell';
    if(c.words.has(idxOf('POLYGLOT'))) cls+=' cell--brand';
    if(c.words.has(idxOf('PURESCRIPT'))) cls+=' cell--pure';
    grid+=`<span class="${cls}" data-words="${[...c.words].join(' ')}">${c.ch}</span>`;
  }
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Polyglot — crossword hero (prototype)</title><link rel="stylesheet" href="../style.css"><style>
.hero{min-height:100vh;display:grid;place-items:center;padding:4rem var(--space);background:radial-gradient(120% 80% at 80% 0%,var(--paper-2),var(--paper) 60%);}
.wrap{display:grid;grid-template-columns:auto minmax(13rem,20rem);gap:clamp(2rem,5vw,4rem);align-items:center;}
.board{display:grid;grid-template-columns:repeat(${L.cols},1fr);gap:2px;}
.cell{aspect-ratio:1;display:grid;place-items:center;font-family:var(--display);font-weight:700;text-transform:uppercase;font-size:clamp(.8rem,1.9vw,1.5rem);color:var(--ink);background:var(--paper);border:1px solid var(--line);border-radius:2px;transition:.12s;}
.cell--blank{background:transparent;border:none;}
.cell--brand{color:var(--primary);border-color:rgba(194,59,34,.4);}
.cell.hl{color:#fff;background:var(--hl,var(--ink));border-color:transparent;transform:scale(1.05);}
/* PureScript lit by default — the resting through-line. Reverts to plain the
   moment any word is hovered (board then contains a .hl cell). */
.board:not(:has(.cell.hl)) .cell--pure{background:var(--ink);color:#fff;border-color:var(--ink);}
.proto{position:fixed;top:1rem;left:1rem;font-size:.7rem;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint);}.proto a{color:var(--link);}
${LEGEND_CSS}@media(max-width:760px){.wrap{grid-template-columns:1fr;}}
</style></head><body>
<p class="proto">Prototype · crossword · <a href="../scrabble/index.html">scrabble board</a> · <a href="../index.html">acrostic</a></p>
<main class="hero"><div class="wrap"><div class="board" id="board">${grid}</div>
${SIDE(L,'../')}</div></main>
<script>${SYNC_JS('.cell')}</script></body></html>`;
}

function renderScrabble(L){
  const ox=Math.floor((15-L.cols)/2), oy=Math.floor((15-L.rows)/2);
  const placed=new Map();
  for(const [k,c] of L.cells){const [x,y]=k.split(',').map(Number);placed.set(`${ox+x-1},${oy+y-1}`,c);}
  const LBL={'3':'TW','2':'DW','t':'TL','d':'DL'};
  let grid='';
  for(let r=0;r<15;r++) for(let q=0;q<15;q++){
    const c=placed.get(`${q},${r}`);
    if(c){const brand=c.words.has(idxOf('POLYGLOT'));
      grid+=`<span class="sq tile${brand?' tile--brand':''}" data-words="${[...c.words].join(' ')}">${c.ch}<i>${POINTS[c.ch]||''}</i></span>`;
    } else { const p=PREMIUM[r][q];
      const cls=p==='*'?'star':p==='3'?'tw':p==='2'?'dw':p==='t'?'tl':p==='d'?'dl':'plain';
      grid+=`<span class="sq ${cls}">${p==='*'?'★':(LBL[p]||'')}</span>`; }
  }
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Polyglot — Scrabble board (prototype)</title><link rel="stylesheet" href="../style.css"><style>
.hero{min-height:100vh;display:grid;place-items:center;padding:3rem var(--space);background:var(--paper-2);}
.wrap{display:grid;grid-template-columns:auto minmax(13rem,20rem);gap:clamp(2rem,5vw,4rem);align-items:center;}
.board{display:grid;grid-template-columns:repeat(15,1fr);gap:3px;background:#2e6f4e;padding:10px;border-radius:6px;box-shadow:0 12px 40px rgba(0,0,0,.25);width:min(78vmin,620px);}
.sq{aspect-ratio:1;display:grid;place-items:center;position:relative;font-family:var(--display);font-weight:700;border-radius:2px;font-size:clamp(.4rem,1vw,.62rem);color:#fff;}
.plain{background:#cdbf9b;}.dl{background:#a9d3ec;color:#1a3a4a;}.tl{background:#3f7fc4;}.dw{background:#e7a9b3;color:#5a1f2a;}.tw{background:#d4503f;}.star{background:#e7a9b3;color:#5a1f2a;font-size:1rem;}
.tile{background:linear-gradient(160deg,#f3e3b3,#e6cf94);color:#3a2a12;border:1px solid #caa95f;box-shadow:inset 0 -2px 0 rgba(0,0,0,.12),0 1px 2px rgba(0,0,0,.25);font-size:clamp(.85rem,2vw,1.4rem);text-transform:uppercase;}
.tile i{position:absolute;right:9%;bottom:3%;font-style:normal;font-size:.4em;opacity:.7;}
.tile--brand{color:var(--primary);}
.tile.hl{transform:translateY(-2px) scale(1.08);box-shadow:0 0 0 2px var(--hl,#fff),0 5px 12px rgba(0,0,0,.4);z-index:2;}
.proto{position:fixed;top:1rem;left:1rem;font-size:.7rem;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint);}.proto a{color:var(--link);}
${LEGEND_CSS}@media(max-width:760px){.wrap{grid-template-columns:1fr;}}
</style></head><body>
<p class="proto">Prototype · scrabble board · <a href="../crossword/index.html">crossword</a> · <a href="../index.html">acrostic</a></p>
<main class="hero"><div class="wrap"><div class="board" id="board">${grid}</div>
${SIDE(L,'../')}</div></main>
<script>${SYNC_JS('.tile')}</script></body></html>`;
}

// ---- run ----
const b = bestPacking();
if(!b){ console.error('No all-placed packing found.'); process.exit(1); }
const L = normalise(b);

const cwDir = PALETTE==='official' ? 'crossword-official' : 'crossword';
const sbDir = PALETTE==='official' ? 'scrabble-official' : 'scrabble';
mkdirSync(join(PUBLIC,cwDir),{recursive:true});
mkdirSync(join(PUBLIC,sbDir),{recursive:true});
writeFileSync(join(PUBLIC,cwDir,'index.html'), renderCrossword(L));
writeFileSync(join(PUBLIC,sbDir,'index.html'), renderScrabble(L));

// ASCII preview
let preview='';
for(let y=1;y<=L.rows;y++){let row='';for(let x=1;x<=L.cols;x++){const c=L.cells.get(`${x},${y}`);row+=c?c.ch:'·';}preview+=row+'\n';}
console.log(`Best packing: ${L.cols}×${L.rows}, ${b.crossings} crossings, fits-board=${b.fits}`);
const unplaced=b.p.placements.filter(q=>q.unplaced).map(q=>q.answer);
if(unplaced.length) console.log('UNPLACED:', unplaced.join(', '));
console.log('Wrote public/crossword/ and public/scrabble/\n');
console.log(preview);
