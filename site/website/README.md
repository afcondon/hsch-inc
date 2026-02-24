# psd3-demo-website

PSD3 documentation and examples website - showcasing PureScript D3 visualizations.

## Overview

Interactive demos and documentation for the PSD3 library ecosystem. Includes examples of:
- Tree layouts and hierarchical visualizations
- Force-directed graphs and simulations
- Sankey diagrams
- TidalCycles pattern visualization (AlgoraveViz)
- Data sonification concepts

## Development

```bash
# Install dependencies
spago install

# Build
spago build

# Bundle for browser
spago bundle --bundle-type app --outfile index.js

# Serve locally
npx http-server -p 8080
```

## Structure

- `src/` - PureScript source code
  - `Component/` - Halogen components
  - `Viz/` - Visualization implementations
  - `Data/` - Data types and loaders
- `public/` - Static assets (HTML, CSS, data files)

## Dependencies

Uses the PSD3 library ecosystem:
- psd3-selection - D3 selection library
- psd3-layout - Layout algorithms
- psd3-simulation - Force simulation
- psd3-tidal - TidalCycles mini-notation parser
- psd3-music - Audio/sonification (experimental)

## License

MIT
