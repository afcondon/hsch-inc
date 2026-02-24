#!/usr/bin/env node
/**
 * md-to-halogen: Build-time preprocessor
 *
 * Converts Markdown files to PureScript Halogen HTML modules.
 *
 * Usage:
 *   node index.js <input.md> [--out <output.purs>] [--module <Module.Name>]
 *   node index.js --dir <content-dir> --out-dir <src-dir>
 */

import MarkdownIt from 'markdown-it';
import fs from 'fs';
import path from 'path';
import { glob } from 'glob';

const md = new MarkdownIt({
  html: false,
  linkify: true,
  typographer: true,
});

// =============================================================================
// AST Types (intermediate representation)
// =============================================================================

// We generate an intermediate AST, then pretty-print it.
// This makes formatting much cleaner.

/**
 * Create a Halogen element node
 */
const elem = (tag, attrs, children) => ({ type: 'elem', tag, attrs, children });
const elemNoAttrs = (tag, children) => ({ type: 'elem', tag, attrs: null, children });
const text = (content) => ({ type: 'text', content });

// =============================================================================
// Token → AST Conversion
// =============================================================================

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

      // Unwrap single paragraph in list item
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
        nodes.push(text(token.content));
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

/**
 * Pretty-print an AST node to Halogen code
 */
function ppNode(node, indent = 0) {
  const pad = '  '.repeat(indent);

  switch (node.type) {
    case 'text':
      return `HH.text "${escapeString(node.content)}"`;

    case 'br':
      return `HH.br_`;

    case 'hr':
      return `HH.hr_`;

    case 'elem': {
      const tag = node.tag;
      const children = node.children || [];

      // Format attributes
      let attrStr = '';
      if (node.attrs) {
        const attrs = Object.entries(node.attrs)
          .map(([k, v]) => `HP.${k} "${escapeString(v)}"`)
          .join(', ');
        attrStr = `[ ${attrs} ]`;
      }

      // Format children
      if (children.length === 0) {
        return node.attrs ? `HH.${tag} ${attrStr} []` : `HH.${tag}_ []`;
      }

      // Check if all children are inline (text, em, strong, code, a, br)
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

      // Block children - format with newlines
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

/**
 * Pretty-print array of nodes
 */
function ppNodes(nodes, indent = 0) {
  const pad = '  '.repeat(indent);
  return nodes.map((n, i) => {
    const code = ppNode(n, indent);
    return i === 0 ? code : `, ${code}`;
  }).join('\n' + pad);
}

// =============================================================================
// Module Generation
// =============================================================================

function generateModule(moduleName, ast) {
  const content = ppNodes(ast, 2);

  return `-- | Auto-generated from Markdown. DO NOT EDIT.
-- | Source: See corresponding .md file in content/
module ${moduleName} where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Rendered markdown content
content :: forall w i. HH.HTML w i
content =
  HH.div_
    [ ${content}
    ]
`;
}

function deriveModuleName(inputPath, baseDir = 'content') {
  const rel = path.relative(baseDir, inputPath);
  const parts = rel.replace(/\.md$/, '').split(path.sep);
  const moduleParts = parts.map(p =>
    p.charAt(0).toUpperCase() + p.slice(1).replace(/-([a-z])/g, (_, c) => c.toUpperCase())
  );
  return 'Content.' + moduleParts.join('.');
}

function deriveOutputPath(inputPath, baseDir = 'content', outDir = 'src/Content') {
  const rel = path.relative(baseDir, inputPath);
  const parts = rel.replace(/\.md$/, '').split(path.sep);
  const outParts = parts.map(p =>
    p.charAt(0).toUpperCase() + p.slice(1).replace(/-([a-z])/g, (_, c) => c.toUpperCase())
  );
  return path.join(outDir, ...outParts) + '.purs';
}

// =============================================================================
// CLI
// =============================================================================

function printHelp() {
  console.log(`
md-to-halogen: Convert Markdown to PureScript Halogen HTML

Usage:
  md-to-halogen <input.md> [options]
  md-to-halogen --dir <content-dir> --out-dir <output-dir>

Options:
  --out <file>       Output .purs file (default: derived from input)
  --module <name>    Module name (default: derived from path)
  --dir <dir>        Process all .md files in directory
  --out-dir <dir>    Output directory for --dir mode (default: src/Content)
  --help             Show this help
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
  let moduleName = null;
  let inputDir = null;
  let outputDir = 'src/Content';

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        outputFile = args[++i];
        break;
      case '--module':
        moduleName = args[++i];
        break;
      case '--dir':
        inputDir = args[++i];
        break;
      case '--out-dir':
        outputDir = args[++i];
        break;
      default:
        if (!args[i].startsWith('-')) {
          inputFile = args[i];
        }
    }
  }

  if (inputDir) {
    const files = await glob(`${inputDir}/**/*.md`);
    console.log(`Processing ${files.length} markdown files...`);

    for (const file of files) {
      const outPath = deriveOutputPath(file, inputDir, outputDir);
      const modName = deriveModuleName(file, inputDir);
      processFile(file, outPath, modName);
    }

    console.log('Done.');
  } else if (inputFile) {
    const outPath = outputFile || deriveOutputPath(inputFile, 'content', outputDir);
    const modName = moduleName || deriveModuleName(inputFile, 'content');
    processFile(inputFile, outPath, modName);
  } else {
    console.error('Error: No input file or directory specified.');
    process.exit(1);
  }
}

function processFile(inputPath, outputPath, moduleName) {
  console.log(`  ${inputPath} → ${outputPath}`);

  const markdown = fs.readFileSync(inputPath, 'utf8');
  const tokens = md.parse(markdown, {});
  const ast = tokensToAST(tokens);
  const moduleCode = generateModule(moduleName, ast);

  const outDir = path.dirname(outputPath);
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outputPath, moduleCode);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
