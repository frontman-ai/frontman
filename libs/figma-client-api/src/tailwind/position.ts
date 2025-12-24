/**
 * Position Tailwind Class Generators
 */

import type { FigmaNode } from "../types.js";
import { needsAbsolutePositioning, needsRelativePositioning } from "../detection.js";
import { numToFixed } from "../utils.js";

/**
 * Generate position classes (absolute, relative, top, left)
 * @param skipCoordinateTransforms - If true, skip x/y coordinate transforms (left/top) but keep positioning type (absolute/relative)
 */
export function positionClasses(node: FigmaNode, skipCoordinateTransforms: boolean = false): string[] {
  const classes: string[] = [];

  // Check if this node needs absolute positioning
  if (needsAbsolutePositioning(node)) {
    classes.push("absolute");

    // Skip x/y coordinates if transforms are baked in (e.g., SVG export)
    if (!skipCoordinateTransforms && node.x !== undefined && node.y !== undefined) {
      const x = numToFixed(node.x);
      const y = numToFixed(node.y);
      classes.push(x === "0" ? "left-0" : `left-[${x}px]`);
      classes.push(y === "0" ? "top-0" : `top-[${y}px]`);
    }
  } else if (node.type === "GROUP") {
    // Groups are always relative
    classes.push("relative");
  }

  // Check if this node should be relative (has absolutely positioned children)
  if (needsRelativePositioning(node) && !classes.includes("absolute")) {
    classes.push("relative");
  }

  return classes;
}


