// VS Code integration FFI
// Opens files in VS Code using the vscode:// URI scheme

// Base path for the project (set when project is loaded)
let projectBasePath = "";

// Map of node paths (module name -> file path)
let nodePaths = new Map();

export const setProjectBasePath = (path) => () => {
  projectBasePath = path;
  console.log("[VSCode] Project base path set to:", path);
};

// Store node paths for double-click lookup
export const setNodePaths = (nodes) => () => {
  nodePaths.clear();
  nodes.forEach((node) => {
    if (node.path) {
      nodePaths.set(node.name, node.path);
    }
  });
  console.log("[VSCode] Stored paths for", nodePaths.size, "nodes");
};

export const openInVSCode = (relativePath) => () => {
  if (!relativePath) {
    console.warn("[VSCode] No path provided");
    return;
  }

  // Construct absolute path
  const absolutePath = projectBasePath
    ? `${projectBasePath}/${relativePath}`
    : relativePath;

  // VS Code URI scheme: vscode://file/absolute/path:line:column
  const uri = `vscode://file${absolutePath}`;
  console.log("[VSCode] Opening:", uri);

  // Open the URI - this triggers VS Code
  window.open(uri, "_self");
};

// Open a module by name (looks up path from stored nodes)
export const openModuleInVSCode = (moduleName) => () => {
  const path = nodePaths.get(moduleName);
  if (path) {
    const absolutePath = projectBasePath
      ? `${projectBasePath}/${path}`
      : path;
    const uri = `vscode://file${absolutePath}`;
    console.log("[VSCode] Opening module:", moduleName, "->", uri);
    window.open(uri, "_self");
  } else {
    console.warn("[VSCode] No path found for module:", moduleName);
  }
};

// Attach double-click handlers to module circles
// Call this after rendering the visualization
export const attachDoubleClickHandlers = (containerSelector) => () => {
  const container = document.querySelector(containerSelector);
  if (!container) return;

  // Find all module circles
  const circles = container.querySelectorAll(".module-node");
  console.log("[VSCode] Attaching double-click to", circles.length, "circles");

  circles.forEach((circle) => {
    // Remove existing handler if any
    circle.removeEventListener("dblclick", circle._vscodeHandler);

    // Add new handler
    circle._vscodeHandler = (e) => {
      e.preventDefault();
      e.stopPropagation();

      // Get the datum from D3's __data__ property
      const datum = circle.__data__;
      if (datum && datum.simNode) {
        const path = datum.simNode.path;
        if (path) {
          const absolutePath = projectBasePath
            ? `${projectBasePath}/${path}`
            : path;
          const uri = `vscode://file${absolutePath}`;
          console.log("[VSCode] Double-click opening:", uri);
          window.open(uri, "_self");
        }
      } else if (datum && datum.name) {
        // Try lookup by name
        const path = nodePaths.get(datum.name);
        if (path) {
          const absolutePath = projectBasePath
            ? `${projectBasePath}/${path}`
            : path;
          const uri = `vscode://file${absolutePath}`;
          console.log("[VSCode] Double-click opening:", uri);
          window.open(uri, "_self");
        }
      }
    };

    circle.addEventListener("dblclick", circle._vscodeHandler);
  });
};

// Get the current focus module from URL params (for VS Code -> Explorer navigation)
export const getFocusModuleFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  return params.get("focus") || "";
};

// Clear the focus param from URL without reload
export const clearFocusParam = () => {
  const url = new URL(window.location);
  url.searchParams.delete("focus");
  window.history.replaceState({}, "", url);
};
