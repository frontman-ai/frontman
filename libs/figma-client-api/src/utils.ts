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
