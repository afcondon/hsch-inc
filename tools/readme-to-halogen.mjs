#!/usr/bin/env node
/**
 * README to Halogen Converter
 *
 * Converts library README.md files to Halogen Main.purs files for
 * the PSD3 library landing pages.
 *
 * Usage:
 *   node tools/readme-to-halogen.mjs [library-name]
 *   node tools/readme-to-halogen.mjs all
 *
 * Examples:
 *   node tools/readme-to-halogen.mjs selection
 *   node tools/readme-to-halogen.mjs layout
 *   node tools/readme-to-halogen.mjs all
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

// Library configuration: fallback values (prefer parsing from README)
const LIBRARY_CONFIG = {
  selection: {
    docsPath: '/docs/selection',
    github: 'afcondon/purescript-psd3-selection',
    version: '0.1.0'
  },
  simulation: {
    docsPath: '/docs/simulation',
    github: 'afcondon/purescript-psd3-simulation',
    version: '0.1.0'
  },
  layout: {
    docsPath: '/docs/layout',
    github: 'afcondon/purescript-psd3-layout',
    version: '0.1.0'
  },
  graph: {
    docsPath: '/docs/graph',
    github: 'afcondon/purescript-psd3-graph',
    version: '0.1.0'
  },
  music: {
    docsPath: '/docs/music',
    github: 'afcondon/purescript-psd3-music',
    version: '0.1.0'
  }
};

/**
 * Parse a Markdown README into structured content
 */
function parseReadme(markdown) {
  const lines = markdown.split('\n');
  const result = {
    title: '',
    packageName: '',
    tagline: '',
    overview: [],
    sections: [],
    codeBlocks: [],
    modules: [],
    // Hero image: [![Alt](image-url)](link-url)
    heroImage: null,  // { alt, imageUrl, linkUrl }
  };

  // Look for hero image pattern: [![Alt](image)](link)
  const heroImagePattern = /^\[\!\[([^\]]*)\]\(([^)]+)\)\]\(([^)]+)\)/;
  for (const line of lines) {
    const match = line.match(heroImagePattern);
    if (match) {
      result.heroImage = {
        alt: match[1],
        imageUrl: match[2],
        linkUrl: match[3]
      };
      break;  // Only take the first one
    }
  }

  let currentSection = null;
  let inCodeBlock = false;
  let codeBlockContent = [];
  let codeBlockLang = '';
  let skipSections = ['Installation', 'Part of PSD3', 'License', 'Modules', 'Status', 'References'];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Handle code blocks
    if (line.startsWith('```')) {
      if (inCodeBlock) {
        // End of code block
        result.codeBlocks.push({
          lang: codeBlockLang,
          code: codeBlockContent.join('\n')
        });
        inCodeBlock = false;
        codeBlockContent = [];
        codeBlockLang = '';
      } else {
        // Start of code block
        inCodeBlock = true;
        codeBlockLang = line.slice(3).trim();
      }
      continue;
    }

    if (inCodeBlock) {
      codeBlockContent.push(line);
      continue;
    }

    // H1 title
    if (line.startsWith('# ')) {
      result.title = line.slice(2).trim();
      result.packageName = result.title.replace('purescript-', '');
      continue;
    }

    // H2 sections
    if (line.startsWith('## ')) {
      const heading = line.slice(3).trim();
      if (skipSections.includes(heading)) {
        currentSection = null;
        continue;
      }
      currentSection = { heading, content: [], subsections: [] };
      result.sections.push(currentSection);
      continue;
    }

    // H3 subsections
    if (line.startsWith('### ')) {
      const heading = line.slice(4).trim();
      if (currentSection) {
        currentSection.subsections.push({ heading, content: [] });
      }
      continue;
    }

    // Regular content
    if (line.trim()) {
      // If we're in Overview section, add to overview
      if (currentSection && currentSection.heading === 'Overview') {
        result.overview.push(cleanMarkdown(line));
      }
      // If we're in a subsection, add there
      else if (currentSection && currentSection.subsections.length > 0) {
        const lastSubsection = currentSection.subsections[currentSection.subsections.length - 1];
        lastSubsection.content.push(cleanMarkdown(line));
      }
      // Otherwise add to current section's main content
      else if (currentSection) {
        currentSection.content.push(cleanMarkdown(line));
      }
      // Before any section, could be tagline
      else if (!result.tagline && line.trim() && !line.startsWith('#')) {
        // Skip hero image lines (already parsed above)
        if (heroImagePattern.test(line)) {
          continue;
        }
        // Check if it's a bold tagline (e.g., **Audio interpreter...**)
        const boldMatch = line.match(/^\*\*(.+)\*\*$/);
        if (boldMatch) {
          result.tagline = boldMatch[1];
        } else {
          result.tagline = cleanMarkdown(line);
        }
      }
    }
  }

  // If no explicit tagline found, use first overview paragraph
  if (!result.tagline && result.overview.length > 0) {
    result.tagline = result.overview[0];
  }

  return result;
}

/**
 * Clean markdown formatting from a line
 */
function cleanMarkdown(text) {
  return text
    // Remove bold
    .replace(/\*\*(.+?)\*\*/g, '$1')
    // Remove italic
    .replace(/\*(.+?)\*/g, '$1')
    // Remove inline code (but keep content)
    .replace(/`(.+?)`/g, '$1')
    // Remove links but keep text
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    // Clean up bullet points
    .replace(/^[-*]\s+/, '')
    .trim();
}

/**
 * Escape PureScript string content (handle quotes and special chars)
 */
function escapePS(str) {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');
}

/**
 * Generate the Main.purs file content
 */
function generateMainPurs(readme, libName, config) {
  const title = libName.charAt(0).toUpperCase() + libName.slice(1);

  // Build elaboration sections from parsed content
  const elaborationSections = [];

  for (const section of readme.sections) {
    if (section.heading === 'Overview') continue; // Already used for hero

    // If section has subsections, use those
    if (section.subsections.length > 0) {
      for (const sub of section.subsections) {
        if (sub.content.length > 0) {
          elaborationSections.push({
            heading: sub.heading,
            content: sub.content
          });
        }
      }
    }
    // Otherwise use the section's own content
    else if (section.content.length > 0) {
      elaborationSections.push({
        heading: section.heading,
        content: section.content
      });
    }
  }

  // Find the best code example (prefer purescript, then any)
  let codeSnippet = '';
  const psBlock = readme.codeBlocks.find(b => b.lang === 'purescript');
  if (psBlock) {
    codeSnippet = psBlock.code;
  } else if (readme.codeBlocks.length > 0) {
    // Use first non-bash code block
    const nonBash = readme.codeBlocks.find(b => b.lang !== 'bash');
    if (nonBash) {
      codeSnippet = nonBash.code;
    }
  }

  // Hero text from overview
  const heroText = readme.overview.length > 0
    ? readme.overview[0]
    : readme.tagline;

  // Hero image from README or fallback
  const heroImage = readme.heroImage || {
    alt: `${title} Demo`,
    imageUrl: 'demo.jpeg',
    linkUrl: '#'
  };
  // For the Halogen site, always use local demo.jpeg (copied to public/)
  // but use the linkUrl from the README
  const demoImageSrc = 'demo.jpeg';
  const demoUrl = heroImage.linkUrl;
  const demoAlt = heroImage.alt;

  // Generate the PureScript code
  return `module Main where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)
import PSD3.LibShell as Shell

-- | Library configuration
config :: Shell.LibConfig
config =
  { name: "psd3-${libName}"
  , title: "${title}"
  , tagline: "${escapePS(readme.tagline)}"
  , version: "${config.version}"
  , github: "${config.github}"
  , docsPath: "${config.docsPath}"
  , polyglotUrl: "/"
  }

-- | Main entry point
main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Page component (stateless)
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \\_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
  }

render :: forall m. Unit -> H.ComponentHTML Unit () m
render _ =
  Shell.shell config
    [ Shell.heroWithViz config heroText heroViz
    , Shell.elaboration
        [ ${elaborationSections.map(s =>
          `{ heading: "${escapePS(s.heading)}"
          , content:
              [ ${s.content.map(p => `Shell.para "${escapePS(p)}"`).join('\n              , ')}
              ]
          }`
        ).join('\n        , ')}
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "${escapePS(heroText)}" ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "${demoImageSrc}" "${demoUrl}" "${escapePS(demoAlt)}"

codeSnippet :: String
codeSnippet = """${codeSnippet}"""
`;
}

/**
 * Process a single library
 */
function processLibrary(libName) {
  const config = LIBRARY_CONFIG[libName];
  if (!config) {
    console.error(`Unknown library: ${libName}`);
    console.error(`Available: ${Object.keys(LIBRARY_CONFIG).join(', ')}`);
    return false;
  }

  // Find the README
  const readmePath = join(ROOT, 'visualisation libraries', `purescript-psd3-${libName}`, 'README.md');
  if (!existsSync(readmePath)) {
    console.error(`README not found: ${readmePath}`);
    return false;
  }

  console.log(`Processing ${libName}...`);
  console.log(`  Reading: ${readmePath}`);

  const markdown = readFileSync(readmePath, 'utf8');
  const parsed = parseReadme(markdown);

  console.log(`  Title: ${parsed.title}`);
  console.log(`  Tagline: ${parsed.tagline.slice(0, 60)}...`);
  console.log(`  Sections: ${parsed.sections.map(s => s.heading).join(', ')}`);
  console.log(`  Code blocks: ${parsed.codeBlocks.length}`);

  const mainPurs = generateMainPurs(parsed, libName, config);

  const outputPath = join(ROOT, 'site', `lib-${libName}`, 'src', 'Main.purs');
  console.log(`  Writing: ${outputPath}`);

  writeFileSync(outputPath, mainPurs);
  console.log(`  Done!`);

  return true;
}

// Main
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log('README to Halogen Converter');
  console.log('');
  console.log('Usage:');
  console.log('  node tools/readme-to-halogen.mjs [library-name]');
  console.log('  node tools/readme-to-halogen.mjs all');
  console.log('');
  console.log('Available libraries:');
  for (const lib of Object.keys(LIBRARY_CONFIG)) {
    console.log(`  - ${lib}`);
  }
  process.exit(0);
}

const target = args[0].toLowerCase();

if (target === 'all') {
  console.log('Converting all library READMEs to Halogen...\n');
  let success = 0;
  let failed = 0;
  for (const lib of Object.keys(LIBRARY_CONFIG)) {
    if (processLibrary(lib)) {
      success++;
    } else {
      failed++;
    }
    console.log('');
  }
  console.log(`Done: ${success} succeeded, ${failed} failed`);
} else {
  processLibrary(target);
}
