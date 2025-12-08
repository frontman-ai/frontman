/**
 * Border and Radius Tailwind Class Generators
 */

import type { FigmaNode, ConversionSettings, Mixed, MIXED } from "../types.js";
import { pxToRemToTailwind } from "../utils.js";
import { fillToTailwind } from "../colors.js";
import { BORDER_RADIUS } from "../config.js";

// Type guard for mixed values
function isMixed(value: unknown): value is Mixed {
  return typeof value === "symbol";
}

/**
 * Generate border radius classes
 */
export function borderRadiusClasses(
  node: FigmaNode,
  settings: ConversionSettings
): string[] {
  // Ellipse is always fully rounded
  if (node.type === "ELLIPSE") {
    return ["rounded-full"];
  }

  const getRadiusSuffix = (radius: number): string => {
    const value = pxToRemToTailwind(radius, BORDER_RADIUS, settings);
    return value ? `-${value}` : "";
  };

  // Uniform corner radius
  if (node.cornerRadius !== undefined && !isMixed(node.cornerRadius)) {
    if (node.cornerRadius > 999) {
      return ["rounded-full"];
    }

    const suffix = getRadiusSuffix(node.cornerRadius);
    return suffix ? [`rounded${suffix}`] : ["rounded"];
  }

  // Individual corner radii
  if (node.topLeftRadius !== undefined) {
    const tl = node.topLeftRadius || 0;
    const tr = node.topRightRadius || 0;
    const br = node.bottomRightRadius || 0;
    const bl = node.bottomLeftRadius || 0;

    // All corners equal
    if (tl === tr && tl === br && tl === bl) {
      if (tl === 0) return [];
      const suffix = getRadiusSuffix(tl);
      return suffix ? [`rounded${suffix}`] : ["rounded"];
    }

    // Individual corners
    const classes: string[] = [];
    if (tl > 0) classes.push(`rounded-tl${getRadiusSuffix(tl)}`);
    if (tr > 0) classes.push(`rounded-tr${getRadiusSuffix(tr)}`);
    if (br > 0) classes.push(`rounded-br${getRadiusSuffix(br)}`);
    if (bl > 0) classes.push(`rounded-bl${getRadiusSuffix(bl)}`);
    return classes;
  }

  return [];
}

/**
 * Generate border classes (width and color)
 */
export function borderClasses(
  node: FigmaNode,
  settings: ConversionSettings
): string[] {
  // Safety check for strokes
  if (
    !node.strokes ||
    !Array.isArray(node.strokes) ||
    node.strokes.length === 0
  ) {
    return [];
  }

  const classes: string[] = [];

  // Border width
  const sw = node.strokeWeight;
  if (sw !== undefined && !isMixed(sw) && typeof sw === "number" && sw > 0) {
    classes.push(sw === 1 ? "border" : `border-${sw}`);
  } else if (node.strokeTopWeight !== undefined) {
    const t = node.strokeTopWeight || 0;
    const r = node.strokeRightWeight || 0;
    const b = node.strokeBottomWeight || 0;
    const l = node.strokeLeftWeight || 0;

    if (t === r && t === b && t === l && t > 0) {
      classes.push(t === 1 ? "border" : `border-${t}`);
    } else {
      if (t > 0) classes.push(t === 1 ? "border-t" : `border-t-${t}`);
      if (r > 0) classes.push(r === 1 ? "border-r" : `border-r-${r}`);
      if (b > 0) classes.push(b === 1 ? "border-b" : `border-b-${b}`);
      if (l > 0) classes.push(l === 1 ? "border-l" : `border-l-${l}`);
    }
  }

  // Border color
  try {
    const borderColor = fillToTailwind(node.strokes, "border", settings);
    if (borderColor) {
      classes.push(borderColor);
    }
  } catch {
    // Skip border color if extraction fails
  }

  return classes;
}


