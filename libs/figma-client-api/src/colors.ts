/**
 * Color and Fill Conversion
 * Converts Figma colors and fills to Tailwind classes
 */

import type { RGB, Paint, ConversionSettings } from "./types.js";
import { OPACITY_VALUES, GRADIENT_DIRECTIONS, GRADIENT_ANGLES } from "./config.js";
import {
  rgbToHex,
  nearestColorName,
  nearestValue,
  nearestOpacity,
} from "./utils.js";
import { retrieveTopFill } from "./detection.js";

// ============================================================================
// Color Conversion
// ============================================================================

/**
 * Convert an RGB color to a Tailwind color class
 */
export function colorToTailwind(
  color: RGB,
  prefix: string,
  opacity: number | undefined,
  settings: ConversionSettings
): string {
  // Handle black
  if (color.r === 0 && color.g === 0 && color.b === 0) {
    const opSuffix =
      opacity !== undefined && opacity < 1
        ? `/${nearestOpacity(opacity)}`
        : "";
    return `${prefix}-black${opSuffix}`;
  }

  // Handle white
  if (color.r === 1 && color.g === 1 && color.b === 1) {
    const opSuffix =
      opacity !== undefined && opacity < 1
        ? `/${nearestOpacity(opacity)}`
        : "";
    return `${prefix}-white${opSuffix}`;
  }

  // Convert to hex and find nearest color
  const hex = rgbToHex(color);
  const name = nearestColorName(hex, settings.roundTailwindColors);
  const opSuffix =
    opacity !== undefined && opacity < 1 ? `/${nearestOpacity(opacity)}` : "";

  return `${prefix}-${name}${opSuffix}`;
}

/**
 * Convert a linear gradient to Tailwind classes
 */
export function linearGradientToTailwind(
  fill: Paint,
  settings: ConversionSettings
): string {
  if (!fill.gradientStops || fill.gradientStops.length === 0) {
    return "";
  }

  const handles = fill.gradientHandlePositions;

  // Safety check for gradient handles
  if (!handles || handles.length < 2 || !handles[0] || !handles[1]) {
    // Fallback to first stop color if handles are invalid
    if (fill.gradientStops[0]?.color) {
      return colorToTailwind(fill.gradientStops[0].color, "bg", undefined, settings);
    }
    return "";
  }

  // Calculate angle
  const angle =
    Math.atan2(handles[1].y - handles[0].y, handles[1].x - handles[0].x) *
    (180 / Math.PI);

  const snapped = nearestValue(angle, GRADIENT_ANGLES);
  const dir = GRADIENT_DIRECTIONS[snapped] || "bg-gradient-to-r";

  const stops = fill.gradientStops;
  if (!stops[0]?.color) {
    return "";
  }

  const from = nearestColorName(
    rgbToHex(stops[0].color),
    settings.roundTailwindColors
  );
  const to = stops[stops.length - 1]?.color
    ? nearestColorName(
        rgbToHex(stops[stops.length - 1].color),
        settings.roundTailwindColors
      )
    : from;

  // Handle via color for 3+ stops
  if (stops.length >= 3 && stops[1]?.color) {
    const via = nearestColorName(
      rgbToHex(stops[1].color),
      settings.roundTailwindColors
    );
    return `${dir} from-${from} via-${via} to-${to}`;
  }

  return `${dir} from-${from} to-${to}`;
}

/**
 * Convert fills array to a Tailwind class
 */
export function fillToTailwind(
  fills: Paint[] | undefined,
  prefix: string,
  settings: ConversionSettings
): string {
  // Safety check for undefined or invalid fills
  if (!fills || !Array.isArray(fills)) {
    return "";
  }

  const fill = retrieveTopFill(fills);
  if (!fill) {
    return "";
  }

  // Solid fill
  if (fill.type === "SOLID") {
    if (!fill.color) {
      return "";
    }
    return colorToTailwind(fill.color, prefix, fill.opacity, settings);
  }

  // Linear gradient
  if (fill.type === "GRADIENT_LINEAR") {
    return linearGradientToTailwind(fill, settings);
  }

  // Other gradients - fallback to first stop color
  if (fill.type.startsWith("GRADIENT_")) {
    if (fill.gradientStops?.[0]?.color) {
      return colorToTailwind(fill.gradientStops[0].color, prefix, undefined, settings);
    }
  }

  return "";
}


