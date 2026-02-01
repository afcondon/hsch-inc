// FFI for PackageSetView
import * as d3 from 'd3';

// Clear container
export const clearContainer = (selector) => () => {
  d3.select(selector).selectAll("*").remove();
};

// Create SVG
export const createSvg = (selector) => (width) => (height) => () => {
  d3.select(selector)
    .append("svg")
    .attr("width", width)
    .attr("height", height)
    .attr("class", "package-set-view");
};

// Render packages as rectangles
export const renderPackages = (selector) => (positioned) => (projectPackages) => () => {
  const svg = d3.select(selector).select("svg");

  // Convert PureScript Set to JS Set
  const usedSet = new Set(projectPackages);

  // Create package group
  const packages = svg.append("g")
    .attr("class", "packages");

  // Render each package
  positioned.forEach(p => {
    const isUsed = usedSet.has(p.pkg.name);

    const g = packages.append("g")
      .attr("class", "package")
      .attr("data-name", p.pkg.name)
      .attr("data-layer", p.pkg.topoLayer)
      .attr("data-used", isUsed)
      .style("cursor", "pointer");

    // Rectangle
    g.append("rect")
      .attr("x", p.x)
      .attr("y", p.y)
      .attr("width", p.width)
      .attr("height", p.height)
      .attr("fill", p.color)
      .attr("opacity", p.opacity)
      .attr("stroke", isUsed ? "#333" : "#999")
      .attr("stroke-width", isUsed ? 2 : 0.5)
      .attr("rx", 3);

    // Label (only if rect is tall enough)
    if (p.height >= 12) {
      g.append("text")
        .attr("x", p.x + p.width / 2)
        .attr("y", p.y + p.height / 2)
        .attr("dy", "0.35em")
        .attr("text-anchor", "middle")
        .attr("font-size", Math.min(10, p.height - 2))
        .attr("fill", isUsed ? "#000" : "#666")
        .attr("pointer-events", "none")
        .text(truncate(p.pkg.name, Math.floor(p.width / 6)));
    }

    // Tooltip on hover
    g.append("title")
      .text(`${p.pkg.name}@${p.pkg.version}\nLayer: ${p.pkg.topoLayer}\nDeps: ${p.pkg.depends.length}\n${p.pkg.description || ''}`);

    // Hover handlers
    g.on("mouseenter", function() {
      // Highlight this package
      d3.select(this).select("rect")
        .attr("stroke", "#000")
        .attr("stroke-width", 3);

      // Highlight dependencies (packages this one depends on)
      const deps = new Set(p.pkg.depends);
      packages.selectAll(".package").each(function() {
        const name = d3.select(this).attr("data-name");
        if (deps.has(name)) {
          d3.select(this).select("rect")
            .attr("stroke", "#2196F3")
            .attr("stroke-width", 2);
        }
      });
    });

    g.on("mouseleave", function() {
      // Reset all strokes
      packages.selectAll(".package").each(function() {
        const isUsed = d3.select(this).attr("data-used") === "true";
        d3.select(this).select("rect")
          .attr("stroke", isUsed ? "#333" : "#999")
          .attr("stroke-width", isUsed ? 2 : 0.5);
      });
    });
  });
};

// Truncate string to max length
function truncate(str, maxLen) {
  if (str.length <= maxLen) return str;
  return str.substring(0, maxLen - 1) + "…";
}

// Highlight packages (deps of hovered)
export const highlightPackages_ = (selector) => (hoveredName) => (depSet) => () => {
  const svg = d3.select(selector).select("svg");
  const packages = svg.select(".packages");

  packages.selectAll(".package").each(function() {
    const name = d3.select(this).attr("data-name");
    if (name === hoveredName) {
      d3.select(this).select("rect")
        .attr("stroke", "#000")
        .attr("stroke-width", 3);
    } else if (depSet.has(name)) {
      d3.select(this).select("rect")
        .attr("stroke", "#2196F3")
        .attr("stroke-width", 2);
    }
  });
};

// Clear highlight
export const clearHighlight_ = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  const packages = svg.select(".packages");

  packages.selectAll(".package").each(function() {
    const isUsed = d3.select(this).attr("data-used") === "true";
    d3.select(this).select("rect")
      .attr("stroke", isUsed ? "#333" : "#999")
      .attr("stroke-width", isUsed ? 2 : 0.5);
  });
};

// Legend functions
export const addLegendGroup_ = (selector) => (y) => () => {
  d3.select(selector).select("svg")
    .append("g")
    .attr("class", "legend")
    .attr("transform", `translate(0, ${y})`);
};

export const addLegendBox_ = (selector) => (x) => (color) => (width) => () => {
  d3.select(selector).select("svg .legend")
    .append("rect")
    .attr("x", x)
    .attr("y", 0)
    .attr("width", width - 2)
    .attr("height", 15)
    .attr("fill", color)
    .attr("opacity", 0.7)
    .attr("rx", 2);
};

export const addLegendLabel_ = (selector) => (x) => (text) => () => {
  d3.select(selector).select("svg .legend")
    .append("text")
    .attr("x", x)
    .attr("y", 28)
    .attr("font-size", 10)
    .attr("fill", "#666")
    .text(text);
};
