/**
 * Tailwind Class Generator
 * Combines all generators into a single function
 */

import type { FigmaNode, ConversionSettings } from "../types.js";
import { SKIP_FILL_TYPES } from "../detection.js";
import { fillToTailwind } from "../colors.js";

import { sizeClasses } from "./size.js";
import { paddingClasses, autoLayoutClasses, overflowClasses } from "./layout.js";
import { borderRadiusClasses, borderClasses } from "./border.js";
import { shadowClasses, blendClasses } from "./effects.js";
import { positionClasses } from "./position.js";
import { textAlignClasses } from "./text.js";

// Re-export individual generators for modular use
export { sizeClasses } from "./size.js";
export { paddingClasses, autoLayoutClasses, overflowClasses } from "./layout.js";
export { borderRadiusClasses, borderClasses } from "./border.js";
export { shadowClasses, blendClasses } from "./effects.js";
export { positionClasses } from "./position.js";
export { textAlignClasses, textStyleClasses } from "./text.js";

/**
 * Generate all Tailwind classes for a node
 * @param skipTransforms - If true, skip rotation and x/y coordinate transforms (for SVG nodes where transforms are baked in)
 *                          Note: positioning type (absolute/relative) is still included for layout flow
 */
export function generateTailwindClasses(
  node: FigmaNode,
  settings: ConversionSettings,
  skipTransforms: boolean = false
): string {
  const classes: string[] = [];

  // Position (absolute, relative) - skip x/y coordinates for SVG nodes but keep positioning type
  classes.push(...positionClasses(node, skipTransforms));

  // Size (width, height, min/max)
  classes.push(...sizeClasses(node, settings));

  // Layout (flex, direction, alignment, gap)
  classes.push(...autoLayoutClasses(node, settings));

  // Padding
  classes.push(...paddingClasses(node, settings));

  // Overflow
  classes.push(...overflowClasses(node));

  // Background color (skip for vector types that need SVG paths)
  if (node.fills && !SKIP_FILL_TYPES.has(node.type)) {
    const bgClass = fillToTailwind(node.fills, "bg", settings);
    if (bgClass) {
      classes.push(bgClass);
    }
  }

  // Border radius
  classes.push(...borderRadiusClasses(node, settings));

  // Border
  classes.push(...borderClasses(node, settings));

  // Shadows and blur
  classes.push(...shadowClasses(node, settings));

  // Blend mode, opacity, rotation, visibility - skip rotation for SVG nodes
  classes.push(...blendClasses(node, skipTransforms));

  // Text alignment (for TEXT nodes)
  if (node.type === "TEXT") {
    classes.push(...textAlignClasses(node));
  }

  return classes.filter(Boolean).join(" ");
}

/**
 * Safe wrapper for generateTailwindClasses that catches errors
 * @param skipTransforms - If true, skip rotation and position transforms (for SVG nodes where transforms are baked in)
 */
export function safeGenerateTailwindClasses(
  node: FigmaNode,
  settings: ConversionSettings,
  skipTransforms: boolean = false
): string {
  try {
    return generateTailwindClasses(node, settings, skipTransforms);
  } catch (e) {
    console.warn(
      `Tailwind generation failed for ${node.name}:`,
      e instanceof Error ? e.message : e
    );
    return "";
  }
}


