#!/usr/bin/env node
/**
 * page-compiler: Single-file page definition to Halogen component
 *
 * Compiles a markdown file with layout frontmatter into a complete
 * Halogen component with CSS grid layout and viz component slots.
 *
 * Format:
 *   ---
 *   title: Page Title
 *   module: My.Module.Name
 *   layout:
 *     - [A, B]
 *     - [C, C]
 *     - [D, E]
 *   ---
 *
 *   ## A: Section Title
 *   Content here...
 *   {{viz:ComponentName props="value"}}
 *
 *   ## B.custom-class: Another Section
 *   More content with custom CSS class...
 *
 *   ## C.my-styles:
 *   Section with custom class but no title...
 *
 * Section syntax:
 *   ## X:           → section-X class only
 *   ## X.foo-bar:   → section-X AND foo-bar classes
 */

import MarkdownIt from 'markdown-it';
import YAML from 'yaml';
import fs from 'fs';
import path from 'path';

const md = new MarkdownIt({
  html: false,
  linkify: true,
  typographer: true,
});

// =============================================================================
// Frontmatter Parsing
// =============================================================================

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) {
    return { frontmatter: {}, body: content };
  }
  const frontmatter = YAML.parse(match[1]);
  const body = match[2];
  return { frontmatter, body };
}

// =============================================================================
// Layout Parsing
// =============================================================================

/**
 * Parse layout array into CSS grid template
 * Input: [['A', 'B'], ['C', 'C'], ['D', 'E']]
 * Output: { css: "...", areas: ['A', 'B', 'C', 'D', 'E'] }
 */
function parseLayout(layout) {
  if (!layout || !Array.isArray(layout)) {
    return { css: '', areas: [], gridTemplateAreas: '' };
  }

  const numCols = Math.max(...layout.map(r => r.length));
  const areas = new Set();

  // Normalize rows to have same number of columns by repeating last cell
  const rows = layout.map(row => {
    const cells = row.map(cell => {
      areas.add(cell);
      return cell;
    });
    // Pad row to numCols by repeating the last cell
    while (cells.length < numCols) {
      cells.push(cells[cells.length - 1]);
    }
    return `"${cells.join(' ')}"`;
  });

  const gridTemplateAreas = rows.join('\n    ');

  const css = `
.page-grid {
  display: grid;
  grid-template-columns: repeat(${numCols}, 1fr);
  grid-template-areas:
    ${gridTemplateAreas};
  gap: 2rem;
  padding: 2rem;
}

${[...areas].map(a => `.section-${a} { grid-area: ${a}; }`).join('\n')}

@media (max-width: 768px) {
  .page-grid {
    grid-template-columns: 1fr;
    grid-template-areas: ${[...areas].map(a => `"${a}"`).join(' ')};
  }
}
`;

  return { css, areas: [...areas], gridTemplateAreas };
}

// =============================================================================
// Section Parsing
// =============================================================================

/**
 * Split body into sections by ## [A-Z]: pattern
 * Handles empty titles and titles on the same line
 * Supports optional CSS class: ## A.simpsons-donuts: Title
 */
function parseSections(body) {
  // Match ## A: or ## A.class-name: or ## A: Title or ## A.class-name: Title
  const sectionRegex = /^## ([A-Z])(?:\.([a-z][a-z0-9-]*))?:[ \t]*(.*)$/gm;
  const sections = [];
  let match;

  // Find all section headers
  const headers = [];
  while ((match = sectionRegex.exec(body)) !== null) {
    headers.push({
      code: match[1],
      cssClass: match[2] || null,  // Optional CSS class
      title: match[3].trim(),
      start: match.index,
      headerEnd: match.index + match[0].length,
    });
  }

  // Extract content between headers
  for (let i = 0; i < headers.length; i++) {
    const header = headers[i];
    const nextStart = headers[i + 1]?.start ?? body.length;
    const content = body.slice(header.headerEnd, nextStart).trim();

    sections.push({
      code: header.code,
      cssClass: header.cssClass,  // Optional CSS class (null if not specified)
      title: header.title,  // May be empty string, that's OK
      content,
    });
  }

  return sections;
}

/**
 * Parse viz placeholders from content
 * {{viz:ComponentName prop="value"}}
 */
function parseVizPlaceholders(content) {
  const vizRegex = /\{\{viz:(\w+)(?:\s+([^}]*))?\}\}/g;
  const vizzes = [];
  let match;

  while ((match = vizRegex.exec(content)) !== null) {
    const name = match[1];
    const propsStr = match[2] || '';

    // Simple prop parsing (key="value" or key=value)
    const props = {};
    const propRegex = /(\w+)=(?:"([^"]*)"|(\S+))/g;
    let propMatch;
    while ((propMatch = propRegex.exec(propsStr)) !== null) {
      props[propMatch[1]] = propMatch[2] ?? propMatch[3];
    }

    vizzes.push({
      name,
      props,
      placeholder: match[0],
      index: match.index,
    });
  }

  return vizzes;
}

// =============================================================================
// Markdown to Halogen AST (reused from md-to-halogen)
// =============================================================================

const elem = (tag, attrs, children) => ({ type: 'elem', tag, attrs, children });
const elemNoAttrs = (tag, children) => ({ type: 'elem', tag, attrs: null, children });
const text = (content) => ({ type: 'text', content });
const viz = (name, props) => ({ type: 'viz', name, props });

function tokensToAST(tokens) {
  const nodes = [];
  let i = 0;

  while (i < tokens.length) {
    const token = tokens[i];

    switch (token.type) {
      case 'heading_open': {
        const level = token.tag;
        const contentToken = tokens[i + 1];
        const children = inlineToAST(contentToken.children || []);
        nodes.push(elemNoAttrs(level, children));
        i += 3;
        break;
      }

      case 'paragraph_open': {
        const contentToken = tokens[i + 1];
        const children = inlineToAST(contentToken.children || []);
        nodes.push(elemNoAttrs('p', children));
        i += 3;
        break;
      }

      case 'blockquote_open': {
        const innerTokens = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'blockquote_close') {
          innerTokens.push(tokens[i]);
          i++;
        }
        const children = tokensToAST(innerTokens);
        nodes.push(elemNoAttrs('blockquote', children));
        i++;
        break;
      }

      case 'bullet_list_open': {
        const innerTokens = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'bullet_list_close') {
          innerTokens.push(tokens[i]);
          i++;
        }
        const children = listItemsToAST(innerTokens);
        nodes.push(elemNoAttrs('ul', children));
        i++;
        break;
      }

      case 'ordered_list_open': {
        const innerTokens = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'ordered_list_close') {
          innerTokens.push(tokens[i]);
          i++;
        }
        const children = listItemsToAST(innerTokens);
        nodes.push(elemNoAttrs('ol', children));
        i++;
        break;
      }

      case 'hr': {
        nodes.push({ type: 'hr' });
        i++;
        break;
      }

      case 'code_block':
      case 'fence': {
        nodes.push(elemNoAttrs('pre', [elemNoAttrs('code', [text(token.content.trimEnd())])]));
        i++;
        break;
      }

      default:
        i++;
    }
  }

  return nodes;
}

function listItemsToAST(tokens) {
  const items = [];
  let i = 0;

  while (i < tokens.length) {
    if (tokens[i].type === 'list_item_open') {
      const innerTokens = [];
      i++;
      while (i < tokens.length && tokens[i].type !== 'list_item_close') {
        innerTokens.push(tokens[i]);
        i++;
      }

      if (innerTokens.length === 3 && innerTokens[0].type === 'paragraph_open') {
        const children = inlineToAST(innerTokens[1].children || []);
        items.push(elemNoAttrs('li', children));
      } else {
        const children = tokensToAST(innerTokens);
        items.push(elemNoAttrs('li', children));
      }
      i++;
    } else {
      i++;
    }
  }

  return items;
}

function inlineToAST(tokens) {
  const nodes = [];
  let i = 0;

  while (i < tokens.length) {
    const token = tokens[i];

    switch (token.type) {
      case 'text': {
        // Check for viz placeholder in text
        const vizMatch = token.content.match(/\{\{viz:(\w+)(?:\s+([^}]*))?\}\}/);
        if (vizMatch) {
          // Split around the viz placeholder
          const before = token.content.slice(0, vizMatch.index);
          const after = token.content.slice(vizMatch.index + vizMatch[0].length);

          if (before) nodes.push(text(before));

          const name = vizMatch[1];
          const propsStr = vizMatch[2] || '';
          const props = {};
          const propRegex = /(\w+)=(?:"([^"]*)"|(\S+))/g;
          let propMatch;
          while ((propMatch = propRegex.exec(propsStr)) !== null) {
            props[propMatch[1]] = propMatch[2] ?? propMatch[3];
          }
          nodes.push(viz(name, props));

          if (after) nodes.push(text(after));
        } else {
          nodes.push(text(token.content));
        }
        i++;
        break;
      }

      case 'softbreak': {
        nodes.push(text(' '));
        i++;
        break;
      }

      case 'hardbreak': {
        nodes.push({ type: 'br' });
        i++;
        break;
      }

      case 'em_open': {
        const innerNodes = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'em_close') {
          if (tokens[i].type === 'text') {
            innerNodes.push(text(tokens[i].content));
          }
          i++;
        }
        nodes.push(elemNoAttrs('em', innerNodes));
        i++;
        break;
      }

      case 'strong_open': {
        const innerNodes = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'strong_close') {
          if (tokens[i].type === 'text') {
            innerNodes.push(text(tokens[i].content));
          }
          i++;
        }
        nodes.push(elemNoAttrs('strong', innerNodes));
        i++;
        break;
      }

      case 'link_open': {
        const href = token.attrGet('href') || '';
        const innerNodes = [];
        i++;
        while (i < tokens.length && tokens[i].type !== 'link_close') {
          if (tokens[i].type === 'text') {
            innerNodes.push(text(tokens[i].content));
          }
          i++;
        }
        nodes.push(elem('a', { href, target: '_blank' }, innerNodes));
        i++;
        break;
      }

      case 'code_inline': {
        nodes.push(elemNoAttrs('code', [text(token.content)]));
        i++;
        break;
      }

      default:
        i++;
    }
  }

  return nodes;
}

/**
 * Convert section content to AST, handling viz placeholders specially
 */
function sectionContentToAST(content) {
  // First, temporarily replace viz placeholders to prevent markdown parsing them
  const vizzes = [];
  let i = 0;
  const placeholder = (idx) => `VIZPLACEHOLDER${idx}ENDVIZ`;

  const contentWithPlaceholders = content.replace(
    /\{\{viz:(\w+)(?:\s+([^}]*))?\}\}/g,
    (match, name, propsStr) => {
      const props = {};
      if (propsStr) {
        const propRegex = /(\w+)=(?:"([^"]*)"|(\S+))/g;
        let propMatch;
        while ((propMatch = propRegex.exec(propsStr)) !== null) {
          props[propMatch[1]] = propMatch[2] ?? propMatch[3];
        }
      }
      vizzes.push({ name, props });
      return placeholder(i++);
    }
  );

  // Parse markdown
  const tokens = md.parse(contentWithPlaceholders, {});
  const ast = tokensToAST(tokens);

  // Replace placeholders in AST with viz nodes
  function replacePlaceholders(nodes) {
    const result = [];
    for (const node of nodes) {
      if (node.type === 'text') {
        // Check if text contains a viz placeholder
        const match = node.content.match(/VIZPLACEHOLDER(\d+)ENDVIZ/);
        if (match) {
          const idx = parseInt(match[1], 10);
          // Split text around placeholder
          const before = node.content.slice(0, match.index);
          const after = node.content.slice(match.index + match[0].length);
          if (before.trim()) result.push(text(before));
          result.push(viz(vizzes[idx].name, vizzes[idx].props));
          if (after.trim()) result.push(text(after));
        } else {
          result.push(node);
        }
      } else if (node.type === 'elem' && node.children) {
        result.push({ ...node, children: replacePlaceholders(node.children) });
      } else {
        result.push(node);
      }
    }
    return result;
  }

  return replacePlaceholders(ast);
}

// =============================================================================
// AST → Halogen Code Pretty Printer
// =============================================================================

function escapeString(str) {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');
}

function ppNode(node, indent = 0) {
  const pad = '  '.repeat(indent);

  switch (node.type) {
    case 'text':
      return `HH.text "${escapeString(node.content)}"`;

    case 'br':
      return `HH.br_`;

    case 'hr':
      return `HH.hr_`;

    case 'viz':
      // Generate component slot
      const propsStr = Object.keys(node.props).length > 0
        ? ` { ${Object.entries(node.props).map(([k, v]) => `${k}: "${v}"`).join(', ')} }`
        : '';
      return `HH.slot _${node.name.toLowerCase()} unit ${node.name}.component${propsStr} absurd`;

    case 'elem': {
      const tag = node.tag;
      const children = node.children || [];

      let attrStr = '';
      if (node.attrs) {
        const attrs = Object.entries(node.attrs)
          .map(([k, v]) => `HP.${k} "${escapeString(v)}"`)
          .join(', ');
        attrStr = `[ ${attrs} ]`;
      }

      if (children.length === 0) {
        return node.attrs ? `HH.${tag} ${attrStr} []` : `HH.${tag}_ []`;
      }

      const allInline = children.every(c =>
        c.type === 'text' || c.type === 'br' ||
        (c.type === 'elem' && ['em', 'strong', 'code', 'a'].includes(c.tag))
      );

      if (allInline) {
        const childStrs = children.map(c => ppNode(c, 0));
        const childrenStr = childStrs.join(', ');
        return node.attrs
          ? `HH.${tag} ${attrStr} [ ${childrenStr} ]`
          : `HH.${tag}_ [ ${childrenStr} ]`;
      }

      const innerPad = '  '.repeat(indent + 1);
      const childStrs = children.map(c => ppNode(c, indent + 1));
      const childrenStr = childStrs.map((s, i) =>
        i === 0 ? `${innerPad}${s}` : `${innerPad}, ${s}`
      ).join('\n');

      return node.attrs
        ? `HH.${tag} ${attrStr}\n${innerPad}[\n${childrenStr}\n${innerPad}]`
        : `HH.${tag}_\n${innerPad}[\n${childrenStr}\n${innerPad}]`;
    }

    default:
      return `-- Unknown node: ${JSON.stringify(node)}`;
  }
}

function ppNodes(nodes, indent = 0) {
  const pad = '  '.repeat(indent);
  return nodes.map((n, i) => {
    const code = ppNode(n, indent);
    return i === 0 ? code : `, ${code}`;
  }).join('\n' + pad);
}

// =============================================================================
// Code Generation
// =============================================================================

function generateModule(config) {
  const { moduleName, title, layout, sections, vizComponents } = config;

  const layoutInfo = parseLayout(layout);

  // Generate section render functions
  const sectionFunctions = sections.map(section => {
    const ast = sectionContentToAST(section.content);
    const content = ppNodes(ast, 3);

    // Only include h2 if there's a title
    const titleLine = section.title
      ? `[ HH.h2_ [ HH.text "${escapeString(section.title)}" ]\n    , ${content}\n    ]`
      : `[ ${content}\n    ]`;

    const comment = section.title
      ? `-- | Section ${section.code}: ${section.title}`
      : `-- | Section ${section.code}`;

    // Build class list: always include section-X, optionally include custom class
    const classes = [`HH.ClassName "page-section"`, `HH.ClassName "section-${section.code}"`];
    if (section.cssClass) {
      classes.push(`HH.ClassName "${section.cssClass}"`);
    }
    const classesStr = classes.join(', ');

    return `
${comment}
renderSection${section.code} :: forall m. H.ComponentHTML Action Slots m
renderSection${section.code} =
  HH.div
    [ HP.classes [ ${classesStr} ] ]
    ${titleLine}`;
  }).join('\n');

  // Generate viz imports
  const vizImports = [...new Set(vizComponents)].map(name =>
    `import ${name} as ${name}`
  ).join('\n');

  // Generate slot types
  const slotTypes = [...new Set(vizComponents)].map(name =>
    `${name.toLowerCase()} :: H.Slot ${name}.Query Void Unit`
  ).join('\n  , ');

  // Generate slot proxies
  const slotProxies = [...new Set(vizComponents)].map(name =>
    `_${name.toLowerCase()} :: Proxy "${name.toLowerCase()}"\n_${name.toLowerCase()} = Proxy`
  ).join('\n\n');

  // Generate render function with grid
  const sectionCalls = sections.map(s => `renderSection${s.code}`).join('\n      , ');

  return `-- | Auto-generated page component. DO NOT EDIT.
-- | Source: See corresponding .md file
-- | Generated by: tools/page-compiler
module ${moduleName} where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Type.Proxy (Proxy(..))

${vizImports}

-- =============================================================================
-- Types
-- =============================================================================

type State = {}

data Action = Initialize

data Query a = NoOp a

type Slots =
  ( ${slotTypes || '-- No viz slots'}
  )

-- =============================================================================
-- Slot Proxies
-- =============================================================================

${slotProxies || '-- No slot proxies'}

-- =============================================================================
-- Component
-- =============================================================================

component :: forall i o m. MonadAff m => H.Component Query i o m
component = H.mkComponent
  { initialState: \\_ -> {}
  , render
  , eval: H.mkEval H.defaultEval
      { initialize = Just Initialize
      }
  }

-- =============================================================================
-- Render
-- =============================================================================

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render _state =
  HH.div
    [ HP.classes [ HH.ClassName "page-container" ] ]
    [ HH.h1_ [ HH.text "${escapeString(title)}" ]
    , HH.div
        [ HP.classes [ HH.ClassName "page-grid" ] ]
        [ ${sectionCalls}
        ]
    ]
${sectionFunctions}

-- =============================================================================
-- Styles (copy to CSS file)
-- =============================================================================
{-
${layoutInfo.css}
-}
`;
}

// =============================================================================
// CLI
// =============================================================================

function printHelp() {
  console.log(`
page-compiler: Compile markdown with layout to Halogen component

Usage:
  page-compiler <input.md> [--out <output.purs>]

Options:
  --out <file>    Output .purs file (default: derived from input)
  --css <file>    Output CSS file for grid layout
  --help          Show this help

Example:
  page-compiler simpsons.md --out src/Page/Simpsons.purs --css public/simpsons-grid.css
`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help')) {
    printHelp();
    process.exit(0);
  }

  let inputFile = null;
  let outputFile = null;
  let cssFile = null;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        outputFile = args[++i];
        break;
      case '--css':
        cssFile = args[++i];
        break;
      default:
        if (!args[i].startsWith('-')) {
          inputFile = args[i];
        }
    }
  }

  if (!inputFile) {
    console.error('Error: No input file specified.');
    process.exit(1);
  }

  // Read and parse
  const content = fs.readFileSync(inputFile, 'utf8');
  const { frontmatter, body } = parseFrontmatter(content);

  const title = frontmatter.title || 'Untitled Page';
  const moduleName = frontmatter.module || 'Page.Generated';
  const layout = frontmatter.layout || [];

  const sections = parseSections(body);

  // Collect viz components from all sections
  const vizComponents = [];
  for (const section of sections) {
    const vizzes = parseVizPlaceholders(section.content);
    vizzes.forEach(v => vizComponents.push(v.name));
  }

  console.log(`Compiling ${inputFile}...`);
  console.log(`  Title: ${title}`);
  console.log(`  Module: ${moduleName}`);
  console.log(`  Sections: ${sections.map(s => s.code).join(', ')}`);
  console.log(`  Viz components: ${[...new Set(vizComponents)].join(', ') || 'none'}`);

  // Generate module
  const moduleCode = generateModule({
    moduleName,
    title,
    layout,
    sections,
    vizComponents,
  });

  // Output
  if (outputFile) {
    const outDir = path.dirname(outputFile);
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(outputFile, moduleCode);
    console.log(`  → ${outputFile}`);
  } else {
    console.log('\n' + moduleCode);
  }

  // CSS output
  if (cssFile) {
    const layoutInfo = parseLayout(layout);
    fs.writeFileSync(cssFile, layoutInfo.css);
    console.log(`  → ${cssFile}`);
  }

  console.log('Done.');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
