/**
 * Utility Functions
 * General-purpose helpers for value conversion and matching
 */

import type { RGB, ConversionSettings } from "./types.js";
import {
  LAYOUT_SIZE,
  BORDER_RADIUS,
  FONT_SIZE,
  LINE_HEIGHT,
  BLUR,
  COLOR_MAP,
  OPACITY_VALUES,
} from "./config.js";

// ============================================================================
// Number Formatting
// ============================================================================

/**
 * Format a number with up to 2 decimal places, removing trailing zeros
 */
export function numToFixed(n: number): string {
  if (Number.isInteger(n)) {
    return n.toString();
  }
  return n.toFixed(2).replace(/\.?0+$/, "");
}

// ============================================================================
// Value Matching
// ============================================================================

/**
 * Find the nearest value in an array to the goal
 */
export function nearestValue(goal: number, arr: readonly number[]): number {
  return arr.reduce((prev, curr) =>
    Math.abs(curr - goal) < Math.abs(prev - goal) ? curr : prev
  );
}

/**
 * Find an exact match within tolerance (0.05)
 */
export function exactValue(
  goal: number,
  arr: readonly number[]
): number | null {
  for (const v of arr) {
    if (Math.abs(goal - v) <= 0.05) {
      return v;
    }
  }
  return null;
}

/**
 * Find nearest value within a percentage threshold
 */
export function nearestWithThreshold(
  goal: number,
  arr: readonly number[],
  thresholdPercent: number
): number | null {
  const nearest = nearestValue(goal, arr);
  const percentDiff = (Math.abs(nearest - goal) / goal) * 100;
  return percentDiff <= thresholdPercent ? nearest : null;
}

// ============================================================================
// Tailwind Value Conversion
// ============================================================================

/**
 * Convert px value to Tailwind class suffix via rem conversion
 */
export function pxToRemToTailwind(
  val: number,
  map: Record<number, string>,
  settings: ConversionSettings
): string {
  const keys = Object.keys(map).map(Number);
  const rem = val / settings.baseFontSize;

  // Try exact match first
  const exact = exactValue(rem, keys);
  if (exact !== null) {
    return map[exact];
  }

  // Try threshold rounding if enabled
  if (settings.roundTailwindValues) {
    const thresh = nearestWithThreshold(rem, keys, settings.thresholdPercent);
    if (thresh !== null) {
      return map[thresh];
    }
  }

  // Fallback to arbitrary value
  return `[${numToFixed(val)}px]`;
}

/**
 * Convert px value to Tailwind class suffix (direct px matching)
 */
export function pxToTailwind(
  val: number,
  map: Record<number, string>,
  settings: ConversionSettings
): string {
  const keys = Object.keys(map).map(Number);

  // Try exact match first
  const exact = exactValue(val, keys);
  if (exact !== null) {
    return map[exact];
  }

  // Try threshold rounding if enabled
  if (settings.roundTailwindValues) {
    const thresh = nearestWithThreshold(val, keys, settings.thresholdPercent);
    if (thresh !== null) {
      return map[thresh];
    }
  }

  // Fallback to arbitrary value
  return `[${numToFixed(val)}px]`;
}

/**
 * Convert px to Tailwind layout size class suffix
 */
export function pxToLayoutSize(
  val: number,
  settings: ConversionSettings
): string {
  const scaled = (val * 16) / settings.baseFontSize;
  const result = pxToTailwind(scaled, LAYOUT_SIZE, settings);
  return result || `[${numToFixed(val)}px]`;
}

/**
 * Convert px to Tailwind border radius class suffix
 */
export function pxToBorderRadius(
  val: number,
  settings: ConversionSettings
): string {
  return pxToRemToTailwind(val, BORDER_RADIUS, settings);
}

/**
 * Convert px to Tailwind font size class suffix
 */
export function pxToFontSize(
  val: number,
  settings: ConversionSettings
): string {
  return pxToRemToTailwind(val, FONT_SIZE, settings);
}

/**
 * Convert px to Tailwind line height class suffix
 */
export function pxToLineHeight(
  val: number,
  settings: ConversionSettings
): string {
  return pxToRemToTailwind(val, LINE_HEIGHT, settings);
}

/**
 * Convert px to Tailwind blur class suffix
 */
export function pxToBlur(val: number, settings: ConversionSettings): string {
  return pxToTailwind(val, BLUR, settings);
}

// ============================================================================
// Color Conversion
// ============================================================================

/**
 * Convert RGB (0-1 range) to hex string
 */
export function rgbToHex(color: RGB): string {
  const r = Math.round(color.r * 255);
  const g = Math.round(color.g * 255);
  const b = Math.round(color.b * 255);
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

/**
 * Parse hex color to RGB values (0-255)
 */
export function hexToRgb(hex: string): { r: number; g: number; b: number } {
  return {
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  };
}

/**
 * Calculate Euclidean distance between two colors
 */
export function colorDistance(
  c1: { r: number; g: number; b: number },
  c2: { r: number; g: number; b: number }
): number {
  return Math.sqrt(
    (c1.r - c2.r) ** 2 + (c1.g - c2.g) ** 2 + (c1.b - c2.b) ** 2
  );
}

/**
 * Find nearest Tailwind color name for a hex color
 */
export function nearestColorName(
  hex: string,
  roundColors: boolean
): string {
  const hexLower = hex.toLowerCase();

  // Exact match
  if (COLOR_MAP[hexLower]) {
    return COLOR_MAP[hexLower];
  }

  // If rounding disabled, return arbitrary value
  if (!roundColors) {
    return `[${hex}]`;
  }

  // Find nearest color
  const target = hexToRgb(hex);
  let best = hex;
  let minDist = Infinity;

  for (const colorHex of Object.keys(COLOR_MAP)) {
    const candidate = hexToRgb(colorHex);
    const dist = colorDistance(target, candidate);
    if (dist < minDist) {
      minDist = dist;
      best = colorHex;
    }
  }

  // Only use nearest if within reasonable distance
  return minDist < 50 ? COLOR_MAP[best] : `[${hex}]`;
}

/**
 * Get nearest Tailwind opacity class suffix
 */
export function nearestOpacity(opacity: number): number {
  return nearestValue(opacity * 100, OPACITY_VALUES);
}

// ============================================================================
// Binary Conversion
// ============================================================================

/**
 * Convert Uint8Array to base64 data URL
 */
export function uint8ToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return "data:image/png;base64," + btoa(binary);
}

// ============================================================================
// Token Counting
// ============================================================================

/**
 * Estimate token count for a string
 * Uses a rough approximation: ~4 characters per token
 */
function estimateStringTokens(str: string): number {
  return Math.ceil(str.length / 4);
}

/**
 * Estimate token count for a ConvertedNode without serializing large binary data
 * This is much more efficient than JSON.stringify() for nodes with images/SVG
 */
export function estimateNodeTokenCount(node: {
  id?: string;
  name?: string;
  type?: string;
  tailwind?: string;
  textContent?: string | Array<{ text?: string; tailwind?: string }>;
  svg?: string;
  imageBase64?: string;
  warning?: string;
}): number {
  let tokenCount = 0;

  // Count basic properties (keys + values)
  if (node.id) tokenCount += estimateStringTokens(node.id) + 1; // +1 for key
  if (node.name) tokenCount += estimateStringTokens(node.name) + 1;
  if (node.type) tokenCount += estimateStringTokens(node.type) + 1;
  if (node.tailwind) tokenCount += estimateStringTokens(node.tailwind) + 1;
  if (node.warning) tokenCount += estimateStringTokens(node.warning) + 1;

  // Count text content efficiently
  if (node.textContent) {
    if (typeof node.textContent === "string") {
      tokenCount += estimateStringTokens(node.textContent) + 1;
    } else if (Array.isArray(node.textContent)) {
      // Count array overhead + each span
      tokenCount += 2; // array brackets
      for (const span of node.textContent) {
        if (span.text) tokenCount += estimateStringTokens(span.text);
        if (span.tailwind) tokenCount += estimateStringTokens(span.tailwind);
        tokenCount += 2; // object overhead per span
      }
    }
  }

  // For large binary data, use a more efficient estimation
  // Base64 images and SVG can be huge, so we estimate rather than count exactly
  if (node.svg) {
    // SVG: estimate tokens without full serialization
    // Most SVGs have repetitive structure, so we can estimate more efficiently
    tokenCount += Math.ceil(node.svg.length / 5) + 1; // Slightly more efficient for structured data
  }

  if (node.imageBase64) {
    // Base64 images: estimate without counting every character
    // Base64 is ~33% larger than binary, and we can estimate tokens more efficiently
    tokenCount += Math.ceil(node.imageBase64.length / 5) + 1; // More efficient for binary-like data
  }

  // Add overhead for object structure (braces, commas, etc.)
  tokenCount += 3; // Object overhead

  return tokenCount;
}

/**
 * Estimate token count for a JSON-serialized object
 * Uses a rough approximation: ~4 characters per token for JSON content
 * Note: For ConvertedNode objects, use estimateNodeTokenCount() instead for better performance
 */
export function estimateTokenCount(obj: unknown): number {
  try {
    const json = JSON.stringify(obj);
    // Rough estimate: ~4 characters per token for JSON
    // This is a conservative estimate for structured data
    return Math.ceil(json.length / 4);
  } catch {
    // If serialization fails, return 0
    return 0;
  }
}
