/**
 * Size-related Tailwind Class Generators
 * Width, height, min/max constraints
 */

import type { FigmaNode, ConversionSettings } from "../types.js";
import { pxToLayoutSize } from "../utils.js";

/**
 * Generate size classes (width, height, min/max)
 */
export function sizeClasses(
  node: FigmaNode,
  settings: ConversionSettings
): string[] {
  const classes: string[] = [];

  if (node.width === undefined) {
    return classes;
  }

  const parent = node.parent;

  // Width
  if (node.layoutSizingHorizontal === "FILL") {
    classes.push(
      parent?.layoutMode === "HORIZONTAL" ? "flex-1" : "self-stretch"
    );
  } else if (
    node.layoutSizingHorizontal === "FIXED" ||
    !node.layoutSizingHorizontal
  ) {
    classes.push(`w-${pxToLayoutSize(node.width, settings)}`);
  }

  // Height
  if (node.layoutSizingVertical === "FILL") {
    classes.push(parent?.layoutMode === "VERTICAL" ? "flex-1" : "self-stretch");
  } else if (
    node.layoutSizingVertical === "FIXED" ||
    !node.layoutSizingVertical
  ) {
    if (node.height !== undefined) {
      classes.push(`h-${pxToLayoutSize(node.height, settings)}`);
    }
  }

  // Min/Max constraints
  if (node.minWidth) {
    classes.push(`min-w-${pxToLayoutSize(node.minWidth, settings)}`);
  }
  if (node.maxWidth) {
    classes.push(`max-w-${pxToLayoutSize(node.maxWidth, settings)}`);
  }
  if (node.minHeight) {
    classes.push(`min-h-${pxToLayoutSize(node.minHeight, settings)}`);
  }
  if (node.maxHeight) {
    classes.push(`max-h-${pxToLayoutSize(node.maxHeight, settings)}`);
  }

  return classes;
}


