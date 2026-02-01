// Scale Transition FFI - DOM manipulation for animated transitions
import * as d3 from "d3";

// Set opacity on package groups by their IDs
// Works with the new <g class="package-group" data-id="..."> structure
// Now receives Array Int directly from PureScript (no Set conversion needed)
// setOpacityByIdsImpl :: String -> Array Int -> Number -> Effect Unit
export const setOpacityByIdsImpl = (selector) => (idsArray) => (opacity) => () => {
  // Look inside the SVG
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[setOpacityByIds] No SVG found in", selector);
    return;
  }

  // idsArray is already a JS array from PureScript
  const ids = new Set(idsArray);

  // Debug: log what we're looking for
  if (opacity < 0.1 || opacity > 0.9) {
    console.log(`[setOpacityByIds] Looking for ${ids.size} IDs, opacity=${opacity.toFixed(2)}`);
    console.log(`[setOpacityByIds] Sample IDs:`, Array.from(ids).slice(0, 5));
  }

  // Select package groups and set opacity on the whole group
  const groups = svg.selectAll("g.package-group");
  if (groups.empty()) {
    console.warn("[setOpacityByIds] No package groups found in SVG");
    return;
  }

  let matchCount = 0;
  groups.each(function() {
    const id = parseInt(d3.select(this).attr("data-id"), 10);
    if (ids.has(id)) {
      d3.select(this).style("opacity", opacity);
      matchCount++;
    }
  });

  if (opacity < 0.1 || opacity > 0.9) {
    console.log(`[setOpacityByIds] Matched ${matchCount} of ${groups.size()} groups`);
  }
};

// Set radius on a single node by ID
// setRadiusById :: String -> Int -> Number -> Effect Unit
export const setRadiusById = (selector) => (nodeId) => (radius) => () => {
  const container = d3.select(selector);

  container.selectAll("circle")
    .filter(function(d) {
      return d && d.id === nodeId;
    })
    .attr("r", radius);
};

// Set position and radius on a single node by ID
// setPositionById :: String -> Int -> Number -> Number -> Number -> Effect Unit
export const setPositionById = (selector) => (nodeId) => (x) => (y) => (radius) => () => {
  const container = d3.select(selector);

  container.selectAll("circle")
    .filter(function(d) {
      return d && d.id === nodeId;
    })
    .attr("cx", x)
    .attr("cy", y)
    .attr("r", radius);
};

// Set opacity on all elements matching a CSS class
// setClassOpacity :: String -> String -> Number -> Effect Unit
export const setClassOpacity = (containerSelector) => (classSelector) => (opacity) => () => {
  const svg = d3.select(containerSelector).select("svg");
  if (svg.empty()) {
    console.warn("[setClassOpacity] No SVG found in", containerSelector);
    return;
  }

  const elements = svg.selectAll(classSelector);
  if (elements.empty() && (opacity < 0.1 || opacity > 0.9)) {
    console.log(`[setClassOpacity] No elements found for "${classSelector}"`);
  }

  elements.style("opacity", opacity);
};

// Remove transition-specific CSS classes
// removeTransitionClass :: String -> Effect Unit
export const removeTransitionClass = (selector) => () => {
  const container = d3.select(selector);

  container.selectAll(".package-transition-circle")
    .classed("package-transition-circle", false);

  container.selectAll(".fading")
    .classed("fading", false);

  container.selectAll(".remaining")
    .classed("remaining", false);
};

// Alternative approach: select by data-id attribute
// This is more reliable when datum binding may be lost

// Set opacity on nodes by their IDs using data-id attribute
export const setOpacityByIdsAttr = (selector) => (ids) => (opacity) => () => {
  const container = d3.select(selector);

  ids.forEach(id => {
    container.select(`[data-id="${id}"]`)
      .style("opacity", opacity);
  });
};

// Helper to convert PureScript Set to JavaScript array
// (PureScript Set is internally a balanced tree, we need to extract values)
function setToArray(psSet) {
  const result = [];

  function extract(node) {
    if (!node) return;
    // PureScript Set internal structure
    if (node.value0 !== undefined) {
      extract(node.value0); // left subtree
    }
    if (node.value1 !== undefined) {
      result.push(node.value1); // current value
    }
    if (node.value2 !== undefined) {
      extract(node.value2); // right subtree
    }
  }

  extract(psSet);
  return result;
}

// Set viewBox only (for ZoomOut phase)
// setViewBox :: String -> Number -> Number -> Effect Unit
export const setViewBox = (selector) => (newWidth) => (newHeight) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for setViewBox");
    return;
  }

  // Update viewBox - centered at origin
  const viewBox = `${-newWidth/2} ${-newHeight/2} ${newWidth} ${newHeight}`;
  svg.attr("viewBox", viewBox);
};

// Grow circles by multiplier (for PopIn phase, no viewBox change)
// Works with <g class="package-group"> structure - grows the package-circle inside
// Now receives Array Int directly from PureScript (no Set conversion needed)
// growCirclesImpl :: String -> Number -> Array Int -> Effect Unit
export const growCirclesImpl = (selector) => (radiusMult) => (idsArray) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for growCircles in", selector);
    return;
  }

  // idsArray is already a JS array from PureScript
  const idSet = new Set(idsArray);

  console.log(`[growCircles] Growing ${idSet.size} circles, mult=${radiusMult.toFixed(2)}`);

  // Grow package circles that match the remaining IDs
  let matchCount = 0;
  svg.selectAll("g.package-group").each(function() {
    const group = d3.select(this);
    const id = parseInt(group.attr("data-id"), 10);

    if (idSet.has(id)) {
      const circle = group.select("circle.package-circle");
      if (!circle.empty()) {
        // Get original radius (already stored as data-original-r in PackageSetBeeswarm)
        let originalR = parseFloat(circle.attr("data-original-r"));
        if (isNaN(originalR)) {
          originalR = parseFloat(circle.attr("r")) || 5;
          circle.attr("data-original-r", originalR);
        }

        // Apply multiplied radius
        circle.attr("r", originalR * radiusMult);
        matchCount++;
      }
    }
  });

  console.log(`[growCircles] Grew ${matchCount} circles`);
};

// Add module circles inside package groups (for PopIn phase)
// Works with <g class="package-group"> structure - adds modules inside each group
// radiusMult is the FINAL radius multiplier (circles will grow to r * radiusMult)
// addModuleCirclesToPackagesImpl :: String -> Number -> Effect Unit
export const addModuleCirclesToPackagesImpl = (selector) => (radiusMult) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for addModuleCirclesToPackages");
    return;
  }

  console.log(`[addModuleCircles] Adding modules with radiusMult=${radiusMult}`);

  // Find all package groups and add module circles inside them
  svg.selectAll("g.package-group").each(function() {
    const group = d3.select(this);
    const id = group.attr("data-id");
    const packageCircle = group.select("circle.package-circle");

    if (packageCircle.empty()) return;

    // Get ORIGINAL radius and compute FINAL radius after growth
    const originalR = parseFloat(packageCircle.attr("data-original-r")) || parseFloat(packageCircle.attr("r")) || 20;
    const finalR = originalR * radiusMult;
    const fill = packageCircle.attr("fill") || "#888";

    // Check if module group already exists
    let moduleGroup = group.select("g.module-group");

    if (moduleGroup.empty()) {
      // Create module group inside the package group (at 0,0 since group is already positioned)
      moduleGroup = group.append("g")
        .attr("class", "module-group");

      // Add placeholder module circles in a packed arrangement
      // Use FINAL radius for positioning (modules will be visible at full size)
      const numModules = Math.max(3, Math.floor(finalR / 4));  // At least 3 modules, more for bigger circles
      const moduleR = Math.max(2, finalR * 0.12);  // Module radius proportional to final size

      // Simple circle packing approximation - pack within 80% of final radius
      const positions = packCircles(numModules, finalR * 0.75, moduleR);

      positions.forEach((pos, i) => {
        moduleGroup.append("circle")
          .attr("class", "module-circle")
          .attr("cx", pos.x)
          .attr("cy", pos.y)
          .attr("r", moduleR)
          .attr("fill", fill)
          .style("opacity", 0)  // Start invisible (use style, not attr for CSS)
          .attr("stroke", "white")
          .attr("stroke-width", 0.5);
      });

      if (positions.length > 0) {
        console.log(`[addModuleCircles] Package ${id}: originalR=${originalR.toFixed(1)}, finalR=${finalR.toFixed(1)}, ${positions.length} modules, moduleR=${moduleR.toFixed(1)}`);
      }
    }
  });
};

// =============================================================================
// NEW: Render from pre-computed packed positions (pure PureScript packing)
// =============================================================================

// Render module circles from pre-computed packed positions
// Takes array of packed packages, each with positioned modules
// renderPackedModulesImpl :: String -> Array PackedPackageData -> Number -> Effect Unit
export const renderPackedModulesImpl = (selector) => (packedPackages) => (opacity) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for renderPackedModules");
    return;
  }

  console.log(`[renderPackedModules] Rendering ${packedPackages.length} packages, opacity=${opacity.toFixed(2)}`);

  packedPackages.forEach(pkg => {
    // Find the package group by data-id
    const group = svg.select(`g.package-group[data-id="${pkg.packageId}"]`);
    if (group.empty()) {
      console.warn(`[renderPackedModules] No group found for package ${pkg.packageId} (${pkg.name})`);
      return;
    }

    // Get color from existing package circle (more reliable than data)
    const packageCircle = group.select("circle.package-circle");
    const color = packageCircle.empty() ? (pkg.color || "#888") : (packageCircle.attr("fill") || pkg.color || "#888");

    // Check if module group already exists
    let moduleGroup = group.select("g.module-group");
    if (moduleGroup.empty()) {
      moduleGroup = group.append("g")
        .attr("class", "module-group");
    }

    // Bind module data and create/update circles
    const modules = moduleGroup.selectAll("circle.module-circle")
      .data(pkg.modules, d => d.nodeId);

    // Enter: create new circles (solid fill, slight transparency for depth)
    modules.enter()
      .append("circle")
      .attr("class", "module-circle")
      .attr("data-id", d => d.nodeId)
      .attr("cx", d => d.x)
      .attr("cy", d => d.y)
      .attr("r", d => d.r)
      .attr("fill", color)
      .attr("fill-opacity", 0.85)  // Solid but with slight transparency
      .attr("stroke", "white")
      .attr("stroke-width", 0.5)
      .style("opacity", opacity);  // This animates during transition

    // Update: update existing circles (in case positions changed)
    modules
      .attr("cx", d => d.x)
      .attr("cy", d => d.y)
      .attr("r", d => d.r)
      .style("opacity", opacity);

    // Exit: remove old circles
    modules.exit().remove();

    if (pkg.modules.length > 0) {
      console.log(`[renderPackedModules] Rendered ${pkg.modules.length} modules for ${pkg.name}, color=${color}`);
    }
  });
};

// Update opacity of all module circles (for animation)
// setModuleOpacity :: String -> Number -> Effect Unit
export const setModuleOpacity = (selector) => (opacity) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  svg.selectAll("circle.module-circle")
    .style("opacity", opacity);
};

// =============================================================================
// Force Layout Reheat (after PopIn to resolve overlaps)
// =============================================================================

// Reheat force simulation with updated collision radii based on packed data
// Returns the simulation handle for cleanup
// reheatWithPackedRadii :: String -> Array PackedPackageData -> Effect Unit
export const reheatWithPackedRadii = (selector) => (packedPackages) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for reheatWithPackedRadii");
    return null;
  }

  // IMPORTANT: Stop any existing simulation to prevent position fights
  const existingSim = svg.node().__beeswarmSimulation;
  if (existingSim) {
    console.log("[reheatWithPackedRadii] Stopping existing beeswarm simulation");
    existingSim.stop();
    svg.node().__beeswarmSimulation = null;
  }

  // Get viewBox dimensions
  const viewBox = svg.attr("viewBox").split(" ").map(Number);
  const width = viewBox[2];
  const height = viewBox[3];

  // Build radius lookup from packed data
  const radiusMap = new Map();
  packedPackages.forEach(pkg => {
    radiusMap.set(pkg.packageId, pkg.enclosingRadius);
  });

  console.log(`[reheatWithPackedRadii] Building simulation for ${packedPackages.length} packages`);

  // Collect nodes from DOM with current positions and new radii
  const nodes = [];
  const groups = svg.selectAll("g.package-group");

  groups.each(function() {
    const group = d3.select(this);
    const id = parseInt(group.attr("data-id"), 10);

    // Get current position from transform
    const transform = group.attr("transform");
    const match = transform && transform.match(/translate\(([^,]+),\s*([^)]+)\)/);
    const x = match ? parseFloat(match[1]) : 0;
    const y = match ? parseFloat(match[2]) : 0;

    // Get radius from packed data (or current circle)
    let radius = radiusMap.get(id);
    if (radius === undefined) {
      const circle = group.select("circle.package-circle");
      radius = parseFloat(circle.attr("r")) || 20;
    }

    nodes.push({ id, x, y, radius, group });
  });

  console.log(`[reheatWithPackedRadii] Collected ${nodes.length} nodes`);

  // Create force simulation
  const simulation = d3.forceSimulation(nodes)
    // Keep roughly in place (weak centering)
    .force("x", d3.forceX(d => d.x).strength(0.05))
    .force("y", d3.forceY(d => d.y).strength(0.05))
    // Strong collision to prevent overlaps
    .force("collide", d3.forceCollide(d => d.radius + 5).strength(0.8).iterations(3))
    .alphaDecay(0.02)
    .on("tick", () => {
      // Update group transforms
      nodes.forEach(node => {
        // Clamp to viewBox bounds
        const padding = 50;
        node.x = Math.max(-width/2 + padding, Math.min(width/2 - padding, node.x));
        node.y = Math.max(-height/2 + padding, Math.min(height/2 - padding, node.y));
        node.group.attr("transform", `translate(${node.x}, ${node.y})`);
      });
    })
    .on("end", () => {
      console.log("[reheatWithPackedRadii] Simulation settled");
    });

  // Start with high alpha for active settling
  simulation.alpha(0.8).restart();

  // Store for potential future cleanup
  svg.node().__beeswarmSimulation = simulation;

  return simulation;
};

// Animate package groups from source to target positions
// moveGroupsToPositions :: String -> Array { id :: Int, x :: Number, y :: Number } -> Number -> Effect Unit
export const moveGroupsToPositions = (selector) => (targets) => (progress) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  // Build lookup from id to target position
  const targetMap = new Map();
  targets.forEach(t => targetMap.set(t.id, { x: t.x, y: t.y }));

  svg.selectAll("g.package-group").each(function() {
    const group = d3.select(this);
    const id = parseInt(group.attr("data-id"), 10);
    const target = targetMap.get(id);

    if (!target) return;  // Not in target set

    // Get source position from data attribute (set at start of transition)
    let sourceX = parseFloat(group.attr("data-source-x"));
    let sourceY = parseFloat(group.attr("data-source-y"));

    // If no source stored, read from current transform and store it
    if (isNaN(sourceX) || isNaN(sourceY)) {
      const transform = group.attr("transform");
      const match = transform && transform.match(/translate\(([^,]+),\s*([^)]+)\)/);
      sourceX = match ? parseFloat(match[1]) : 0;
      sourceY = match ? parseFloat(match[2]) : 0;
      group.attr("data-source-x", sourceX);
      group.attr("data-source-y", sourceY);
    }

    // Interpolate position
    const x = sourceX + (target.x - sourceX) * progress;
    const y = sourceY + (target.y - sourceY) * progress;
    group.attr("transform", `translate(${x}, ${y})`);
  });
};

// Render treemap backdrop (rectangles) with given opacity
// renderTreemapBackdrop :: String -> Array PackageRect -> Number -> Effect Unit
export const renderTreemapBackdrop = (selector) => (packageRects) => (opacity) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  // Check if backdrop group exists, create if not
  let backdrop = svg.select("g.treemap-backdrop");
  if (backdrop.empty()) {
    // Insert at the beginning so it's behind the package groups
    backdrop = svg.insert("g", ":first-child")
      .attr("class", "treemap-backdrop");

    console.log(`[renderTreemapBackdrop] Creating ${packageRects.length} rectangles`);

    // Create rectangles for each package
    backdrop.selectAll("rect.package-rect")
      .data(packageRects, d => d.name)
      .join("rect")
      .attr("class", "package-rect")
      .attr("x", d => d.x)
      .attr("y", d => d.y)
      .attr("width", d => d.width)
      .attr("height", d => d.height)
      .attr("fill", "#0a3d62")  // Blueprint blue
      .attr("stroke", "rgba(255, 255, 255, 0.3)")
      .attr("stroke-width", 1);

    // Add package labels
    backdrop.selectAll("text.package-label")
      .data(packageRects, d => d.name)
      .join("text")
      .attr("class", "package-label")
      .attr("x", d => d.x + 4)
      .attr("y", d => d.y + 12)
      .attr("fill", "rgba(255, 255, 255, 0.5)")
      .attr("font-size", "10px")
      .attr("font-family", "monospace")
      .text(d => d.name);
  }

  // Update opacity
  backdrop.style("opacity", opacity);
};

// Set opacity on package groups (for fade out during crossfade)
// setPackageGroupsOpacity :: String -> Number -> Effect Unit
export const setPackageGroupsOpacity = (selector) => (opacity) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  svg.selectAll("g.package-group")
    .style("opacity", opacity);
};

// Transition viewBox smoothly
// transitionViewBox :: String -> Number -> Number -> Number -> Number -> Number -> Effect Unit
export const transitionViewBox = (selector) => (targetMinX) => (targetMinY) => (targetWidth) => (targetHeight) => (progress) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  // Store source viewBox on first call
  if (!svg.node().__sourceViewBox) {
    const current = svg.attr("viewBox").split(" ").map(Number);
    svg.node().__sourceViewBox = {
      minX: current[0],
      minY: current[1],
      width: current[2],
      height: current[3]
    };
  }

  const src = svg.node().__sourceViewBox;

  // Interpolate
  const minX = src.minX + (targetMinX - src.minX) * progress;
  const minY = src.minY + (targetMinY - src.minY) * progress;
  const width = src.width + (targetWidth - src.width) * progress;
  const height = src.height + (targetHeight - src.height) * progress;

  svg.attr("viewBox", `${minX} ${minY} ${width} ${height}`);

  // Clear source when transition completes
  if (progress >= 1.0) {
    svg.node().__sourceViewBox = null;
  }
};

// Stop the beeswarm simulation (prevents competing with transitions)
// stopBeeswarmSimulation :: String -> Effect Unit
export const stopBeeswarmSimulation = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  const existingSim = svg.node().__beeswarmSimulation;
  if (existingSim) {
    console.log("[ScaleTransition] Stopping beeswarm simulation to prevent position conflicts");
    existingSim.stop();
    svg.node().__beeswarmSimulation = null;
  }
};

// Read current positions of package groups from DOM
// Returns array of { id, x, y, r } objects
// getCurrentPositions :: String -> Effect (Array { id :: Int, x :: Number, y :: Number, r :: Number })
export const getCurrentPositions = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for getCurrentPositions");
    return [];
  }

  const positions = [];
  svg.selectAll("g.package-group").each(function() {
    const group = d3.select(this);
    const id = parseInt(group.attr("data-id"), 10);

    // Get position from transform
    const transform = group.attr("transform");
    const match = transform && transform.match(/translate\(([^,]+),\s*([^)]+)\)/);
    const x = match ? parseFloat(match[1]) : 0;
    const y = match ? parseFloat(match[2]) : 0;

    // Get current radius
    const circle = group.select("circle.package-circle");
    const r = parseFloat(circle.attr("r")) || 20;

    positions.push({ id, x, y, r });
  });

  console.log(`[getCurrentPositions] Read ${positions.length} positions`);
  return positions;
};

// Read current positions of package groups from DOM, keyed by NAME
// Use this when matching between different data sources (packageSetData vs modelData)
// Returns array of { name, x, y, r } objects
// getCurrentPositionsByName :: String -> Effect (Array { name :: String, x :: Number, y :: Number, r :: Number })
export const getCurrentPositionsByName = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) {
    console.warn("[ScaleTransition] No SVG found for getCurrentPositionsByName in", selector);
    return [];
  }

  const positions = [];
  svg.selectAll("g.package-group").each(function() {
    const group = d3.select(this);
    const name = group.attr("data-name");

    if (!name) {
      console.warn("[getCurrentPositionsByName] Group missing data-name attribute");
      return;
    }

    // Get position from transform
    const transform = group.attr("transform");
    const match = transform && transform.match(/translate\(([^,]+),\s*([^)]+)\)/);
    const x = match ? parseFloat(match[1]) : 0;
    const y = match ? parseFloat(match[2]) : 0;

    // Get current radius - try both class names (beeswarm uses plain 'circle', others use 'circle.package-circle')
    let circle = group.select("circle.package-circle");
    if (circle.empty()) {
      circle = group.select("circle");
    }
    const r = circle.empty() ? 20 : (parseFloat(circle.attr("r")) || 20);

    positions.push({ name, x, y, r });
  });

  console.log(`[getCurrentPositionsByName] Read ${positions.length} positions from ${selector}`);
  return positions;
};

// Grow package circles to their target enclosing radius
// Uses the enclosingRadius from packed data
// growToPackedRadii :: String -> Array PackedPackageData -> Number -> Effect Unit
export const growToPackedRadiiImpl = (selector) => (packedPackages) => (progress) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  packedPackages.forEach(pkg => {
    const group = svg.select(`g.package-group[data-id="${pkg.packageId}"]`);
    if (group.empty()) return;

    const circle = group.select("circle.package-circle");
    if (circle.empty()) return;

    // Get original radius
    let originalR = parseFloat(circle.attr("data-original-r"));
    if (isNaN(originalR)) {
      originalR = parseFloat(circle.attr("r")) || 10;
      circle.attr("data-original-r", originalR);
    }

    // Interpolate from original to enclosing radius
    const targetR = pkg.enclosingRadius;
    const currentR = originalR + (targetR - originalR) * progress;
    circle.attr("r", currentR);
  });
};

// Remove faded packages from DOM (GUP exit pattern)
// Called at end of FadeOut phase to remove packages that have faded to opacity 0
// removeFadedPackagesImpl :: String -> Array Int -> Effect Unit
export const removeFadedPackagesImpl = (selector) => (fadingIds) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  console.log(`[ScaleTransition] Removing ${fadingIds.length} faded packages from DOM (GUP exit)`);

  let removedCount = 0;
  fadingIds.forEach(id => {
    const group = svg.select(`g.package-group[data-id="${id}"]`);
    if (!group.empty()) {
      group.remove();
      removedCount++;
    }
  });

  console.log(`[ScaleTransition] Removed ${removedCount} package groups`);
};

// Remove beeswarm elements after treemap transition completes
// Removes package groups and any beeswarm-specific elements, keeps treemap backdrop
// removeBeeswarmElements :: String -> Effect Unit
export const removeBeeswarmElements = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  console.log("[ScaleTransition] Removing beeswarm elements after treemap transition");

  // Remove all package groups (circles from the beeswarm)
  const removed = svg.selectAll("g.package-group").remove();
  console.log(`[ScaleTransition] Removed ${removed.size()} package groups`);

  // Remove any beeswarm-specific elements
  svg.selectAll(".module-circle").remove();
  svg.selectAll(".package-transition-circle").remove();

  // Clear any stored simulation reference
  if (svg.node().__beeswarmSimulation) {
    svg.node().__beeswarmSimulation.stop();
    svg.node().__beeswarmSimulation = null;
  }
};

// Remove treemap backdrop (used when zooming out from treemap to beeswarm)
// removeTreemapBackdrop :: String -> Effect Unit
export const removeTreemapBackdrop = (selector) => () => {
  const svg = d3.select(selector).select("svg");
  if (svg.empty()) return;

  const backdrop = svg.select("g.treemap-backdrop");
  if (!backdrop.empty()) {
    console.log("[ScaleTransition] Removing treemap backdrop");
    backdrop.remove();
  }
};
