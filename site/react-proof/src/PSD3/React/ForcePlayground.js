// ForcePlayground FFI - Rendering and math helpers

// Group colors matching PureScript
const groupColors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"];
const groupNames = ["Research", "Industry", "Government", "Community"];

// Render the force playground visualization with click callback
export const renderPlaygroundWithCallback = (containerId) => (nodes) => (links) => (onNodeClick) => () => {
  const container = document.getElementById(containerId);
  if (!container) return;

  // Clear existing content
  container.innerHTML = '';

  // Create SVG
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", "800");
  svg.setAttribute("height", "600");
  svg.setAttribute("viewBox", "-400 -300 800 600");
  container.appendChild(svg);

  // Create groups for layering
  const linksGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
  linksGroup.setAttribute("class", "links");
  svg.appendChild(linksGroup);

  const nodesGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
  nodesGroup.setAttribute("class", "nodes");
  svg.appendChild(nodesGroup);

  // Build node lookup for link rendering
  const nodeMap = {};
  nodes.forEach(n => { nodeMap[n.id] = n; });

  // Render links
  links.forEach(link => {
    const source = nodeMap[link.source];
    const target = nodeMap[link.target];
    if (!source || !target) return;

    const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
    line.setAttribute("x1", source.x);
    line.setAttribute("y1", source.y);
    line.setAttribute("x2", target.x);
    line.setAttribute("y2", target.y);
    line.setAttribute("stroke", "#999");
    line.setAttribute("stroke-opacity", 0.3 + link.weight * 0.4);
    line.setAttribute("stroke-width", 0.5 + link.weight * 1.5);
    linksGroup.appendChild(line);
  });

  // Render nodes
  nodes.forEach(node => {
    const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    circle.setAttribute("cx", node.x);
    circle.setAttribute("cy", node.y);
    // Radius based on importance (4-10)
    circle.setAttribute("r", 4 + node.importance * 6);
    circle.setAttribute("fill", groupColors[node.group] || "#69b3a2");
    circle.setAttribute("stroke", "#fff");
    circle.setAttribute("stroke-width", 1.5);
    circle.setAttribute("opacity", 0.8);
    circle.style.cursor = "pointer";

    // Click handler - pass node info to callback
    circle.addEventListener("click", () => {
      const nodeInfo = {
        id: node.id,
        group: node.group,
        groupName: groupNames[node.group] || "Unknown",
        importance: node.importance
      };
      onNodeClick(nodeInfo)();
    });

    nodesGroup.appendChild(circle);
  });
};

// Math helpers
export const cos = (x) => Math.cos(x);
export const sin = (x) => Math.sin(x);
export const unsafeRound = (x) => Math.round(x);
