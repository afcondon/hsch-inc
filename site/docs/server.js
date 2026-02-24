const express = require('express');
const path = require('path');
const fs = require('fs');
const { glob } = require('glob');
const Asciidoctor = require('@asciidoctor/core')();

const app = express();
const PORT = 9001;

// Base directory for all repos
const BASE_DIR = path.join(__dirname, '..');

// Documentation locations
const DOC_SOURCES = [
  { name: 'psd3-selection', path: 'visualisation libraries/purescript-psd3-selection/docs' },
  { name: 'psd3-simulation', path: 'visualisation libraries/purescript-psd3-simulation/docs' },
  { name: 'psd3-layout', path: 'visualisation libraries/purescript-psd3-layout/docs' },
  { name: 'psd3-graph', path: 'visualisation libraries/purescript-psd3-graph/docs' },
  { name: 'psd3-react', path: 'psd3-react/docs' },
  { name: 'psd3-sheetless', path: 'psd3-sheetless/docs' },
  { name: 'purerl-tidal', path: 'showcase apps/algorave/purerl-tidal/docs' },
  { name: 'psd3-tidal', path: 'showcase apps/algorave/purescript-psd3-tidal/docs' },
];

// CSS for rendered documentation
const CSS = `
<style>
  :root {
    --bg: #ffffff;
    --text: #333333;
    --link: #0066cc;
    --code-bg: #f5f5f5;
    --border: #e0e0e0;
    --nav-bg: #f8f9fa;
    --highlight: #fff3cd;
  }

  * { box-sizing: border-box; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: var(--text);
    margin: 0;
    padding: 0;
    display: flex;
    min-height: 100vh;
  }

  nav {
    width: 280px;
    min-width: 280px;
    background: var(--nav-bg);
    border-right: 1px solid var(--border);
    padding: 20px;
    overflow-y: auto;
    position: fixed;
    top: 0;
    left: 0;
    height: 100vh;
  }

  nav h2 {
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #666;
    margin-top: 20px;
    margin-bottom: 8px;
  }

  nav h2:first-child { margin-top: 0; }

  nav ul {
    list-style: none;
    padding: 0;
    margin: 0 0 15px 0;
  }

  nav li { margin: 4px 0; }

  nav a {
    color: var(--link);
    text-decoration: none;
    font-size: 14px;
    display: block;
    padding: 4px 8px;
    border-radius: 4px;
  }

  nav a:hover {
    background: rgba(0, 102, 204, 0.1);
  }

  nav a.active {
    background: var(--link);
    color: white;
  }

  main {
    flex: 1;
    padding: 40px 60px;
    max-width: 900px;
    margin-left: 280px;
  }

  h1 { font-size: 2em; margin-top: 0; border-bottom: 2px solid var(--border); padding-bottom: 10px; }
  h2 { font-size: 1.5em; margin-top: 2em; }
  h3 { font-size: 1.2em; margin-top: 1.5em; }

  code {
    font-family: 'SF Mono', Monaco, 'Courier New', monospace;
    font-size: 0.9em;
    background: var(--code-bg);
    padding: 2px 6px;
    border-radius: 3px;
  }

  pre {
    background: var(--code-bg);
    padding: 16px;
    border-radius: 6px;
    overflow-x: auto;
    border: 1px solid var(--border);
  }

  pre code {
    background: none;
    padding: 0;
  }

  .listingblock { margin: 1em 0; }
  .listingblock .title { font-weight: bold; margin-bottom: 0.5em; color: #666; }

  table {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
  }

  th, td {
    border: 1px solid var(--border);
    padding: 8px 12px;
    text-align: left;
  }

  th { background: var(--nav-bg); }

  .admonitionblock {
    margin: 1em 0;
    padding: 12px 16px;
    border-radius: 6px;
    border-left: 4px solid;
  }

  .admonitionblock.note { background: #e7f3ff; border-color: #0066cc; }
  .admonitionblock.tip { background: #e6f7e6; border-color: #28a745; }
  .admonitionblock.warning { background: var(--highlight); border-color: #ffc107; }
  .admonitionblock.important { background: #ffe6e6; border-color: #dc3545; }

  a { color: var(--link); }

  .breadcrumb {
    font-size: 14px;
    color: #666;
    margin-bottom: 20px;
  }

  .breadcrumb a { color: #666; }
  .breadcrumb a:hover { color: var(--link); }

  .home-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 20px;
    margin-top: 30px;
  }

  .doc-card {
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 20px;
    transition: box-shadow 0.2s;
  }

  .doc-card:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  }

  .doc-card h3 {
    margin: 0 0 10px 0;
    font-size: 1.1em;
  }

  .doc-card p {
    margin: 0;
    font-size: 14px;
    color: #666;
  }

  .doc-card a {
    text-decoration: none;
    color: inherit;
    display: block;
  }
</style>
`;

// Asciidoctor options
const asciidoctorOptions = {
  safe: 'safe',
  attributes: {
    'source-highlighter': 'highlight.js',
    'icons': 'font',
    'sectanchors': true,
    'toc': false,
  }
};

// Find all .adoc files in a directory
async function findAdocFiles(docPath) {
  const fullPath = path.join(BASE_DIR, docPath);
  if (!fs.existsSync(fullPath)) return [];

  const pattern = path.join(fullPath, '**/*.adoc');
  const files = await glob(pattern, { windowsPathsNoEscape: true });

  return files.map(f => {
    const relative = path.relative(fullPath, f);
    return {
      path: relative,
      name: path.basename(f, '.adoc'),
      fullPath: f
    };
  }).sort((a, b) => a.path.localeCompare(b.path));
}

// Build navigation for a doc source
async function buildNavigation(source) {
  const files = await findAdocFiles(source.path);
  const nav = {};

  for (const file of files) {
    const parts = file.path.split(path.sep);
    let current = nav;

    for (let i = 0; i < parts.length - 1; i++) {
      const part = parts[i];
      if (!current[part]) current[part] = {};
      current = current[part];
    }

    const fileName = parts[parts.length - 1];
    current[fileName] = file;
  }

  return { files, nav };
}

// Render navigation HTML
function renderNavItem(items, basePath, currentPath, depth = 0) {
  let html = '<ul>';

  for (const [key, value] of Object.entries(items)) {
    if (value.fullPath) {
      // It's a file
      const href = `${basePath}/${value.path}`;
      const isActive = currentPath === href;
      const displayName = value.name.replace(/-/g, ' ').replace(/^\w/, c => c.toUpperCase());
      html += `<li><a href="${href}" class="${isActive ? 'active' : ''}">${displayName}</a></li>`;
    } else {
      // It's a directory
      const displayName = key.replace(/-/g, ' ').replace(/^\w/, c => c.toUpperCase());
      html += `<li><strong style="font-size:12px;color:#999;display:block;margin-top:10px;">${displayName}</strong>`;
      html += renderNavItem(value, basePath, currentPath, depth + 1);
      html += '</li>';
    }
  }

  html += '</ul>';
  return html;
}

// Home page
app.get('/', async (req, res) => {
  let cardsHtml = '';

  for (const source of DOC_SOURCES) {
    const fullPath = path.join(BASE_DIR, source.path);
    if (!fs.existsSync(fullPath)) continue;

    const files = await findAdocFiles(source.path);
    const fileCount = files.length;

    // Try to read description from index.adoc
    let description = `${fileCount} documentation files`;
    const indexPath = path.join(fullPath, 'modules/ROOT/pages/index.adoc');
    if (fs.existsSync(indexPath)) {
      try {
        const content = fs.readFileSync(indexPath, 'utf-8');
        const descMatch = content.match(/:description:\s*(.+)/);
        if (descMatch) description = descMatch[1];
      } catch (e) {}
    }

    cardsHtml += `
      <div class="doc-card">
        <a href="/docs/${source.name}">
          <h3>${source.name}</h3>
          <p>${description}</p>
        </a>
      </div>
    `;
  }

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>PSD3 Documentation</title>
  ${CSS}
</head>
<body style="display:block;">
  <main style="margin-left:0;max-width:1200px;margin:0 auto;">
    <h1>PSD3 Documentation</h1>
    <p>Unified documentation for the PSD3 visualization ecosystem.</p>

    <div class="home-grid">
      ${cardsHtml}
    </div>
  </main>
</body>
</html>
  `;

  res.send(html);
});

// Doc index page
app.get('/docs/:source', async (req, res) => {
  const sourceName = req.params.source;
  const source = DOC_SOURCES.find(s => s.name === sourceName);

  if (!source) {
    return res.status(404).send('Documentation not found');
  }

  // Redirect to index.adoc if it exists
  const indexPath = path.join(BASE_DIR, source.path, 'modules/ROOT/pages/index.adoc');
  if (fs.existsSync(indexPath)) {
    return res.redirect(`/docs/${sourceName}/modules/ROOT/pages/index.adoc`);
  }

  // Otherwise show file list
  const { files, nav } = await buildNavigation(source);

  let listHtml = '<ul>';
  for (const file of files) {
    listHtml += `<li><a href="/docs/${sourceName}/${file.path}">${file.path}</a></li>`;
  }
  listHtml += '</ul>';

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${sourceName} - PSD3 Docs</title>
  ${CSS}
</head>
<body style="display:block;">
  <main style="margin-left:0;max-width:900px;margin:0 auto;">
    <div class="breadcrumb"><a href="/">Home</a> / ${sourceName}</div>
    <h1>${sourceName}</h1>
    ${listHtml}
  </main>
</body>
</html>
  `;

  res.send(html);
});

// Render a specific .adoc file
app.get('/docs/:source/*', async (req, res) => {
  const sourceName = req.params.source;
  const filePath = req.params[0];
  const source = DOC_SOURCES.find(s => s.name === sourceName);

  if (!source) {
    return res.status(404).send('Documentation not found');
  }

  const fullPath = path.join(BASE_DIR, source.path, filePath);

  if (!fs.existsSync(fullPath)) {
    return res.status(404).send(`File not found: ${filePath}`);
  }

  // Read and convert the file
  const content = fs.readFileSync(fullPath, 'utf-8');
  const doc = Asciidoctor.load(content, {
    ...asciidoctorOptions,
    attributes: {
      ...asciidoctorOptions.attributes,
      'imagesdir': path.dirname(fullPath),
    }
  });

  const docContent = doc.convert();
  const title = doc.getDocumentTitle() || filePath;

  // Build navigation
  const { nav } = await buildNavigation(source);
  const currentPath = `/docs/${sourceName}/${filePath}`;
  const navHtml = renderNavItem(nav, `/docs/${sourceName}`, currentPath);

  // Build sidebar with all doc sources
  let sidebarHtml = `<h2>${sourceName}</h2>${navHtml}`;
  sidebarHtml += '<h2 style="margin-top:30px;">Other Docs</h2><ul>';
  for (const s of DOC_SOURCES) {
    if (s.name !== sourceName) {
      sidebarHtml += `<li><a href="/docs/${s.name}">${s.name}</a></li>`;
    }
  }
  sidebarHtml += '</ul>';

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${title} - ${sourceName} - PSD3 Docs</title>
  ${CSS}
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js"></script>
  <script>
    // Use Haskell highlighting for PureScript
    hljs.registerAliases('purescript', { languageName: 'haskell' });
    document.addEventListener('DOMContentLoaded', () => hljs.highlightAll());
  </script>
</head>
<body>
  <nav>
    <div style="margin-bottom:20px;">
      <a href="/" style="font-weight:bold;font-size:16px;">PSD3 Docs</a>
    </div>
    ${sidebarHtml}
  </nav>
  <main>
    <div class="breadcrumb">
      <a href="/">Home</a> /
      <a href="/docs/${sourceName}">${sourceName}</a> /
      ${filePath}
    </div>
    ${docContent}
  </main>
</body>
</html>
  `;

  res.send(html);
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║                  PSD3 Documentation Server                  ║
╠════════════════════════════════════════════════════════════╣
║                                                             ║
║   Server running at: http://localhost:${PORT}                 ║
║                                                             ║
║   Documentation sources:                                    ║
${DOC_SOURCES.map(s => `║     • ${s.name.padEnd(20)} ${s.path.substring(0,30).padEnd(30)}║`).join('\n')}
║                                                             ║
╚════════════════════════════════════════════════════════════╝
  `);
});
