# Hello World

This is the first test post for **Hylographic** - a visualization-first blog platform for the PSD3 library documentation.

## What is Hylographic?

Hylographic is built to showcase the [Hylograph](https://github.com/afcondon/purescript-hylograph) visualization library. It supports:

1. **Named Viz Components**: Full Halogen components embedded via `{{viz:ComponentName}}`
2. **MetaHATS Blocks**: HATS code that renders as both syntax-highlighted code AND visualization
3. **Regular Code Blocks**: Standard Prism.js syntax highlighting

## Example Code

Here's some PureScript:

```purescript
renderNode :: forall m. Node -> HH.ComponentHTML Action () m
renderNode node =
  HH.circle
    [ HP.cx node.x
    , HP.cy node.y
    , HP.r 5.0
    , HP.fill "#steelblue"
    ]
```

And some JavaScript:

```javascript
const simulation = d3.forceSimulation(nodes)
  .force("charge", d3.forceManyBody().strength(-30))
  .force("center", d3.forceCenter(width / 2, height / 2))
  .on("tick", ticked);
```

## Embedded Visualizations

Here's an embedded visualization using the `{{viz:ComponentName}}` syntax:

{{viz:HelloViz}}

And here's a force demo:

{{viz:ForceDemo}}

And here's a MetaHATS example showing code alongside visualization:

{{viz:MetaHATS}}

## Features Coming Soon

- **Force layout index**: Articles as nodes, cross-references as edges
- **MetaHATS inline visualization**: Write HATS, see the rendered SVG
- **More viz components**: `{{viz:ForcePlayground}}`

> The goal is to make technical writing about data visualization as visual as possible.

---

*Built with PureScript, Halogen, and Hylograph.*
