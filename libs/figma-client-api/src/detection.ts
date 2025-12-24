/**
 * Node Detection Functions
 * Utilities for detecting node types and characteristics
 */

import type { FigmaNode, FigmaNodeType, ConversionSettings, Paint } from "./types.js";

// ============================================================================
// Node Type Sets
// ============================================================================

/** Vector/shape types that can be exported as SVG */
export const ICON_TYPES = new Set<FigmaNodeType>([
  "VECTOR",
  "BOOLEAN_OPERATION",
  "POLYGON",
  "STAR",
  "LINE",
  "ELLIPSE",
  "RECTANGLE",
]);

/** Container types that can hold children */
export const CONTAINER_TYPES = new Set<FigmaNodeType>([
  "FRAME",
  "GROUP",
  "COMPONENT",
  "INSTANCE",
]);

/** Types that should not be converted to SVG */
export const DISALLOWED_TYPES = new Set<FigmaNodeType>([
  "TEXT",
  "SLICE",
  "CONNECTOR",
  "STICKY",
  "WIDGET",
  "CODE_BLOCK",
]);

/** Types that should skip fill color generation (need SVG paths to render) */
export const SKIP_FILL_TYPES = new Set<FigmaNodeType>([
  "VECTOR",
  "BOOLEAN_OPERATION",
  "LINE",
  "STAR",
  "POLYGON",
]);

// ============================================================================
// Detection Functions
// ============================================================================

/**
 * Check if a node or any of its descendants contains text
 * This is important to avoid converting text-containing nodes to SVG
 */
export function hasTextDescendant(node: FigmaNode): boolean {
  if (node.type === "TEXT") {
    return true;
  }

  if (node.children && node.children.length > 0) {
    return node.children.some(
      (child) => child.visible !== false && hasTextDescendant(child)
    );
  }

  return false;
}

/**
 * Check if a node is likely an icon that should be exported as SVG
 */
export function isLikelyIcon(
  node: FigmaNode,
  settings: ConversionSettings
): boolean {
  // Skip disallowed types
  if (DISALLOWED_TYPES.has(node.type)) {
    return false;
  }

  // Check if node has any visible content
  if (node.visible === false) {
    return false;
  }

  // Must have dimensions
  if (
    node.width === undefined ||
    node.height === undefined ||
    node.width <= 0 ||
    node.height <= 0
  ) {
    return false;
  }

  // Vector types are always icons
  if (ICON_TYPES.has(node.type)) {
    return true;
  }

  // Check for SVG export settings
  if (node.exportSettings?.some((s) => s.format === "SVG")) {
    return true;
  }

  // Small containers with only vector children can be icons
  if (
    CONTAINER_TYPES.has(node.type) &&
    node.width <= settings.maxIconSize &&
    node.height <= settings.maxIconSize
  ) {
    if (node.children && node.children.length > 0) {
      const visibleChildren = node.children.filter((c) => c.visible !== false);

      // Must have visible children
      if (visibleChildren.length === 0) {
        return false;
      }

      // Must not have any text anywhere in the subtree
      if (hasTextDescendant(node)) {
        return false;
      }

      // Must not have disallowed types as direct children
      const hasDisallowed = visibleChildren.some((c) =>
        DISALLOWED_TYPES.has(c.type)
      );

      if (!hasDisallowed) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Check if a container should be exported as a single SVG (vector-only container)
 * This handles cases like decorative backgrounds with many small vectors
 */
export function isVectorOnlyContainer(node: FigmaNode): boolean {
  if (!CONTAINER_TYPES.has(node.type)) {
    return false;
  }

  if (!node.children || node.children.length === 0) {
    return false;
  }

  // CRITICAL: Never convert to SVG if there's any text anywhere in the subtree
  if (hasTextDescendant(node)) {
    return false;
  }

  // Get visible children
  const visibleChildren = node.children.filter((c) => c.visible !== false);
  if (visibleChildren.length === 0) {
    return false;
  }

  // All children must be vector/shape types or nested vector containers
  const allVectors = visibleChildren.every(
    (child) =>
      ICON_TYPES.has(child.type) ||
      (CONTAINER_TYPES.has(child.type) && isVectorOnlyContainer(child))
  );

  return allVectors;
}

/**
 * Check if fills array contains an image fill
 */
export function hasImageFill(fills: FigmaNode["fills"]): boolean {
  return fills?.some((f) => f.type === "IMAGE") ?? false;
}

/**
 * Get the topmost visible fill from fills array
 */
export function retrieveTopFill(
  fills: Paint[] | undefined
): Paint | undefined {
  if (!fills || fills.length === 0) {
    return undefined;
  }
  return [...fills].reverse().find((f) => f.visible !== false);
}

/**
 * Check if a node needs absolute positioning
 */
export function needsAbsolutePositioning(node: FigmaNode): boolean {
  // Explicitly set to ABSOLUTE
  if (node.layoutPositioning === "ABSOLUTE") {
    return true;
  }

  // Parent has no auto-layout - children are positioned by x,y
  const parent = node.parent;
  if (
    parent &&
    (!parent.layoutMode || parent.layoutMode === "NONE") &&
    node.x !== undefined &&
    node.y !== undefined
  ) {
    return true;
  }

  return false;
}

/**
 * Check if a node should have relative positioning (has absolutely positioned children)
 */
export function needsRelativePositioning(node: FigmaNode): boolean {
  if (!node.children) {
    return false;
  }

  return node.children.some(
    (child) =>
      child.layoutPositioning === "ABSOLUTE" ||
      ((!node.layoutMode || node.layoutMode === "NONE") &&
        child.x !== undefined &&
        child.y !== undefined)
  );
}

/**
 * Check if a container node has SVG children (children that will be exported as SVG)
 * Containers wrapping SVG elements should skip transforms since SVG export bakes them in
 */
export function hasSvgChildren(
  node: FigmaNode,
  settings: ConversionSettings
): boolean {
  if (!node.children || node.children.length === 0) {
    return false;
  }

  const visibleChildren = node.children.filter((c) => c.visible !== false);
  if (visibleChildren.length === 0) {
    return false;
  }

  // Check if any child is a vector type or likely icon that would be exported as SVG
  return visibleChildren.some(
    (child) =>
      ICON_TYPES.has(child.type) ||
      (settings.embedVectors && isLikelyIcon(child, settings)) ||
      (CONTAINER_TYPES.has(child.type) && isVectorOnlyContainer(child))
  );
}


