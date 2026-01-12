#!/usr/bin/env node
/**
 * makefile-to-sankey.js
 *
 * Extracts dependency graph from the PSD3 Makefile and outputs
 * Sankey-compatible CSV format.
 *
 * Usage:
 *   node scripts/makefile-to-sankey.js > build-deps.csv
 *   node scripts/makefile-to-sankey.js --json > build-deps.json
 *   node scripts/makefile-to-sankey.js --filter libs
 *   node scripts/makefile-to-sankey.js --filter apps
 */

const fs = require('fs');
const path = require('path');

// Parse command line args
const args = process.argv.slice(2);
const outputJson = args.includes('--json');
const outputSankeyDoc = args.includes('--sankey-doc');
const filterType = args.find(a => a.startsWith('--filter='))?.split('=')[1]
                || (args.includes('--filter') ? args[args.indexOf('--filter') + 1] : null);

// Read Makefile
const makefilePath = path.join(__dirname, '..', 'Makefile');
const makefile = fs.readFileSync(makefilePath, 'utf8');

// Target categories for grouping/coloring
const categories = {
  'lib-tree': 'foundation',
  'lib-graph': 'layer1',
  'lib-layout': 'layer1',
  'lib-selection': 'layer2',
  'lib-music': 'layer3',
  'lib-simulation': 'layer3',
  'lib-showcase-shell': 'layer3',
  'lib-simulation-halogen': 'layer4',
  'lib-astar-demo': 'demo',
  'wasm-kernel': 'wasm',
  'app-wasm': 'app',
  'app-embedding-explorer': 'app',
  'app-sankey': 'app',
  'app-code-explorer': 'app',
  'app-tilted-radio': 'app',
  'ee-server': 'backend',
  'ge-server': 'backend',
  'ee-website': 'frontend',
  'ge-website': 'frontend',
  'landing': 'frontend',
  'ce-server': 'backend',
  'ce2-website': 'frontend',
  'vscode-ext': 'tooling',
  'purerl-tidal': 'backend',
  'ps-tidal': 'frontend',
  'libs': 'aggregate',
  'apps': 'aggregate',
  'all': 'aggregate',
};

// Parse Makefile for dependencies
// Format: target: dep1 dep2 dep3
function parseDependencies(makefile) {
  const deps = [];
  const lines = makefile.split('\n');

  // Targets we care about (skip .PHONY, variables, etc.)
  const targetPattern = /^([a-z][a-z0-9_-]*)\s*:\s*(.*)$/i;

  // Skip these targets
  const skipTargets = new Set([
    'SHELL', 'clean', 'clean-deps', 'check-tools', 'setup',
    'install-python-deps', 'show-config', 'deps-graph', 'help'
  ]);

  // Skip dependencies that are clearly not targets
  const skipDeps = new Set(['\\', '']);

  for (const line of lines) {
    // Skip comments, recipe lines, empty lines, variable assignments
    if (line.startsWith('#') || line.startsWith('\t') || line.trim() === '') {
      continue;
    }
    if (line.includes(':=') || line.includes('?=')) {
      continue;
    }

    const match = line.match(targetPattern);
    if (match) {
      const [, target, depString] = match;

      // Skip .PHONY, special targets, and utility targets
      if (target.startsWith('.') || skipTargets.has(target)) {
        continue;
      }

      // Parse dependencies
      const targetDeps = depString
        .split(/\s+/)
        .map(d => d.replace(/\\$/, '').trim()) // Remove trailing backslash
        .filter(d => d && !d.startsWith('$') && !d.startsWith('#') && !skipDeps.has(d))
        .filter(d => d.length > 0 && /^[a-z]/i.test(d)); // Must start with letter

      if (targetDeps.length > 0) {
        for (const dep of targetDeps) {
          deps.push({
            source: dep,
            target: target,
            value: 1,
            sourceCategory: categories[dep] || 'unknown',
            targetCategory: categories[target] || 'unknown'
          });
        }
      }
    }
  }

  return deps;
}

// Filter dependencies based on type
function filterDeps(deps, filterType) {
  if (!filterType) return deps;

  const libTargets = new Set([
    'lib-tree', 'lib-graph', 'lib-layout', 'lib-selection',
    'lib-music', 'lib-simulation', 'lib-showcase-shell',
    'lib-simulation-halogen', 'lib-astar-demo', 'libs'
  ]);

  const appTargets = new Set([
    'app-wasm', 'app-embedding-explorer', 'app-sankey',
    'app-code-explorer', 'app-tilted-radio', 'apps',
    'wasm-kernel', 'ee-server', 'ge-server', 'ee-website',
    'ge-website', 'landing', 'ce-server', 'ce2-website',
    'vscode-ext', 'purerl-tidal', 'ps-tidal'
  ]);

  if (filterType === 'libs') {
    return deps.filter(d => libTargets.has(d.source) || libTargets.has(d.target));
  } else if (filterType === 'apps') {
    return deps.filter(d => appTargets.has(d.source) || appTargets.has(d.target));
  }

  return deps;
}

// Remove duplicate edges
function dedupe(deps) {
  const seen = new Set();
  return deps.filter(d => {
    const key = `${d.source}->${d.target}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// Main
const allDeps = parseDependencies(makefile);
const filteredDeps = filterDeps(allDeps, filterType);
const uniqueDeps = dedupe(filteredDeps);

// Node type based on category
function getNodeType(category) {
  if (category === 'foundation') return 'source';
  if (category === 'aggregate') return 'sink';
  return 'transform';
}

// Human-readable descriptions
const descriptions = {
  'lib-tree': 'Rose tree data structure - foundation for all PSD3 libraries',
  'lib-graph': 'Graph algorithms and data structures',
  'lib-layout': 'Layout algorithms (tree, pack, sankey)',
  'lib-selection': 'D3-style DOM selections and attributes',
  'lib-music': 'Audio/sonification interpreter',
  'lib-simulation': 'Force-directed graph simulation',
  'lib-showcase-shell': 'Halogen shell for demo applications',
  'lib-simulation-halogen': 'Halogen integration for force simulation',
  'lib-astar-demo': 'A* pathfinding visualization demo',
  'wasm-kernel': 'Rust WASM force simulation kernel',
  'app-wasm': 'WASM force simulation demo application',
  'app-embedding-explorer': 'Word embedding explorer (EE + GE)',
  'app-sankey': 'Annotated Sankey diagram editor',
  'app-code-explorer': 'Code visualization explorer',
  'app-tilted-radio': 'Tidal patterns / algorave editor',
  'ee-server': 'Embedding Explorer Python backend (PurePy)',
  'ge-server': 'Grid Explorer Python backend (PurePy)',
  'ee-website': 'Embedding Explorer Halogen frontend',
  'ge-website': 'Grid Explorer Halogen frontend',
  'landing': 'Hypo-Punter unified landing page',
  'ce-server': 'Code Explorer Node.js backend',
  'ce2-website': 'Code Explorer Halogen frontend',
  'vscode-ext': 'Code Explorer VSCode extension',
  'purerl-tidal': 'Tidal Erlang/OTP backend (Purerl)',
  'ps-tidal': 'Tidal PureScript frontend',
  'libs': 'All PureScript libraries',
  'apps': 'All showcase applications',
  'all': 'Complete build'
};

if (outputSankeyDoc) {
  // Output as SankeyDocument format for psd3-arid-keystone
  const nodeSet = new Set();
  uniqueDeps.forEach(d => {
    nodeSet.add(d.source);
    nodeSet.add(d.target);
  });

  // Calculate node values based on outgoing edge count
  const outgoingCount = {};
  uniqueDeps.forEach(d => {
    outgoingCount[d.source] = (outgoingCount[d.source] || 0) + 1;
  });

  const nodeArray = Array.from(nodeSet);
  const nodes = {};
  nodeArray.forEach(name => {
    const category = categories[name] || 'unknown';
    const nodeType = getNodeType(category);
    nodes[name] = {
      id: name,
      label: name,
      description: descriptions[name] || null,
      nodeType: nodeType,
      inputType: nodeType === 'source' ? null : 'Target',
      outputType: nodeType === 'sink' ? null : 'Target',
      tags: [category],
      style: null,
      value: (outgoingCount[name] || 1) * 20,
      parentGroup: null
    };
  });

  const edges = uniqueDeps.map((d, i) => ({
    id: `e${i + 1}`,
    from: d.source,
    to: d.target,
    label: null,
    edgeType: 'Dependency',
    value: 1,
    style: null
  }));

  const doc = {
    nodes,
    edges,
    groups: {},
    title: 'PSD3 Build Dependencies',
    description: 'Makefile dependency graph for the PSD3 ecosystem'
  };

  console.log(JSON.stringify(doc, null, 2));
} else if (outputJson) {
  // Output as JSON (for programmatic use)
  const nodes = new Set();
  uniqueDeps.forEach(d => {
    nodes.add(d.source);
    nodes.add(d.target);
  });

  const output = {
    nodes: Array.from(nodes).map(name => ({
      name,
      category: categories[name] || 'unknown'
    })),
    links: uniqueDeps.map(d => ({
      source: d.source,
      target: d.target,
      value: d.value
    }))
  };

  console.log(JSON.stringify(output, null, 2));
} else {
  // Output as CSV
  console.log('source,target,value');
  for (const dep of uniqueDeps) {
    console.log(`${dep.source},${dep.target},${dep.value}`);
  }
}
