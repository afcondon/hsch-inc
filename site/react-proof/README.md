# psd3-react

PSD3 integration with React via purescript-react-basic-hooks.

## Overview

This package demonstrates that PSD3 is framework-agnostic. The core PSD3 library doesn't know or care whether it's running inside Halogen, React, or vanilla JS - it just needs a DOM element to render to.

## Installation

```bash
npm install
spago build
```

## Usage

### Basic Pattern

```purescript
import PSD3.React.Hooks (useContainerId)
import PSD3.Render (runD3, select, renderTree, clear)

mkMyViz :: Component { chartData :: Array Number }
mkMyViz = do
  containerId <- useContainerId  -- Generate unique ID outside component
  component "MyViz" \props -> React.do

    useEffectOnce do
      void $ runD3 do
        let selector = "#" <> containerId
        clear selector
        container <- select selector
        renderTree container (myVisualizationAST props.chartData)
      pure mempty

    pure $ R.div
      { id: containerId
      , style: R.css { width: "500px", height: "300px" }
      }
```

### The Pattern Explained

1. **`useContainerId`** - Generate a unique ID when creating the component (runs once)
2. **`useEffectOnce`** (or `useEffect` with deps) - Run D3 when component mounts
3. **`clear selector`** - Remove existing content before re-rendering
4. **`select selector`** - Select the container element
5. **`renderTree`** - Render the PSD3 AST to the container

## Running the Demo

```bash
npm run bundle
npm run serve
# Open http://localhost:8080
```

## How It Works

The integration is thin because PSD3 is already framework-agnostic:

- PSD3 renders to DOM elements via D3.js
- React provides the container element
- `useEffect`/`useLayoutEffect` bridges React's lifecycle to PSD3's imperative rendering

This is the exact same pattern used for Halogen integration - PSD3 doesn't import Halogen or React, it just receives a DOM element selector.

## Comparison with Halogen

| Aspect | Halogen | React |
|--------|---------|-------|
| Container ref | `getHTMLElementRef` | unique ID via `useContainerId` |
| Lifecycle hook | `HalogenM` `liftEffect` | `useEffect` / `useLayoutEffect` |
| Re-render trigger | Halogen state change | React state/props change |
| PSD3 code | Identical | Identical |

## Files

- `src/PSD3/React/Hooks.purs` - `useContainerId` helper
- `src/PSD3/React/Example.purs` - Bar chart and circle examples
- `demo/index.html` - Demo page

## Future Improvements

- Add `selectElement` to psd3-selection for direct element selection (no ID needed)
- Add `useD3Effect` hook that handles cleanup automatically
- Add examples with interactive state updates via React state

## See Also

- [psd3-selection](../purescript-psd3-selection) - Core PSD3 library
- [purescript-react-basic-hooks](https://github.com/purescript-react/purescript-react-basic-hooks) - React hooks for PureScript
