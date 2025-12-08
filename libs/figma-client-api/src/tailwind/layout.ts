/**
 * Layout-related Tailwind Class Generators
 * Auto-layout, padding, gap
 */

import type { FigmaNode, ConversionSettings } from "../types.js";
import { pxToLayoutSize } from "../utils.js";

/**
 * Generate padding classes
 */
export function paddingClasses(
  node: FigmaNode,
  settings: ConversionSettings
): string[] {
  if (!node.layoutMode || node.layoutMode === "NONE") {
    return [];
  }

  const pl = node.paddingLeft || 0;
  const pr = node.paddingRight || 0;
  const pt = node.paddingTop || 0;
  const pb = node.paddingBottom || 0;

  // No padding
  if (pl === 0 && pr === 0 && pt === 0 && pb === 0) {
    return [];
  }

  // All sides equal
  if (pl === pr && pl === pt && pl === pb) {
    return [`p-${pxToLayoutSize(pl, settings)}`];
  }

  // Symmetric (px and py)
  if (pl === pr && pt === pb) {
    const classes: string[] = [];
    if (pl > 0) classes.push(`px-${pxToLayoutSize(pl, settings)}`);
    if (pt > 0) classes.push(`py-${pxToLayoutSize(pt, settings)}`);
    return classes;
  }

  // Individual sides
  const classes: string[] = [];

  if (pl === pr && pl > 0) {
    classes.push(`px-${pxToLayoutSize(pl, settings)}`);
  } else {
    if (pl > 0) classes.push(`pl-${pxToLayoutSize(pl, settings)}`);
    if (pr > 0) classes.push(`pr-${pxToLayoutSize(pr, settings)}`);
  }

  if (pt === pb && pt > 0) {
    classes.push(`py-${pxToLayoutSize(pt, settings)}`);
  } else {
    if (pt > 0) classes.push(`pt-${pxToLayoutSize(pt, settings)}`);
    if (pb > 0) classes.push(`pb-${pxToLayoutSize(pb, settings)}`);
  }

  return classes;
}

/**
 * Generate auto-layout classes (flex, direction, alignment, gap)
 */
export function autoLayoutClasses(
  node: FigmaNode,
  settings: ConversionSettings
): string[] {
  if (!node.layoutMode || node.layoutMode === "NONE") {
    return [];
  }

  const classes: string[] = [];
  const parent = node.parent;

  // Display
  classes.push(parent?.layoutMode === node.layoutMode ? "flex" : "inline-flex");

  // Direction
  if (node.layoutMode === "VERTICAL") {
    classes.push("flex-col");
  }

  // Primary axis alignment (justify-content)
  switch (node.primaryAxisAlignItems) {
    case "CENTER":
      classes.push("justify-center");
      break;
    case "MAX":
      classes.push("justify-end");
      break;
    case "SPACE_BETWEEN":
      classes.push("justify-between");
      break;
    default:
      classes.push("justify-start");
  }

  // Counter axis alignment (align-items)
  switch (node.counterAxisAlignItems) {
    case "CENTER":
      classes.push("items-center");
      break;
    case "MAX":
      classes.push("items-end");
      break;
    case "BASELINE":
      classes.push("items-baseline");
      break;
    default:
      classes.push("items-start");
  }

  // Gap
  if (
    node.itemSpacing &&
    node.itemSpacing > 0 &&
    node.primaryAxisAlignItems !== "SPACE_BETWEEN"
  ) {
    classes.push(`gap-${pxToLayoutSize(node.itemSpacing, settings)}`);
  }

  // Wrap
  if (node.layoutWrap === "WRAP") {
    classes.push("flex-wrap");
  }

  return classes;
}

/**
 * Generate overflow classes
 */
export function overflowClasses(node: FigmaNode): string[] {
  if (node.clipsContent && node.children && node.children.length > 0) {
    return ["overflow-hidden"];
  }
  return [];
}


