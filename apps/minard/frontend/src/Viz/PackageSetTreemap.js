// PackageSetTreemap FFI - Position export for transitions
import * as d3 from "d3";

// Get cell positions from treemap for Treemap → Beeswarm transition
// Reads circle centers from .treemap-package groups
// getCellPositionsImpl :: String -> Effect (Array { name :: String, x :: Number, y :: Number, r :: Number })
export const getCellPositionsImpl = (containerSelector) => () => {
  const svg = d3.select(containerSelector).select("svg");
  if (svg.empty()) {
    console.warn("[PackageSetTreemap] No SVG found for getCellPositions in", containerSelector);
    return [];
  }

  const positions = [];

  svg.selectAll(".treemap-package").each(function() {
    const group = d3.select(this);
    const name = group.attr("data-name");

    if (!name) {
      console.warn("[PackageSetTreemap] Group missing data-name attribute");
      return;
    }

    // Find the circle within this group
    const circle = group.select("circle");
    if (circle.empty()) {
      // If no circle, try to get the rect center
      const rect = group.select("rect");
      if (!rect.empty()) {
        const x = parseFloat(rect.attr("x")) || 0;
        const y = parseFloat(rect.attr("y")) || 0;
        const width = parseFloat(rect.attr("width")) || 0;
        const height = parseFloat(rect.attr("height")) || 0;
        const cx = x + width / 2;
        const cy = y + height / 2;
        const r = Math.min(width, height) / 4; // Estimate radius
        positions.push({ name, x: cx, y: cy, r });
      }
      return;
    }

    const cx = parseFloat(circle.attr("cx")) || 0;
    const cy = parseFloat(circle.attr("cy")) || 0;
    const r = parseFloat(circle.attr("r")) || 10;

    positions.push({ name, x: cx, y: cy, r });
  });

  console.log(`[PackageSetTreemap] Exported ${positions.length} cell positions`);
  return positions;
};
