/**
 * Text-related Tailwind Class Generators
 */

import type { FigmaNode, TextSegment, ConversionSettings } from "../types.js";
import { FONT_SIZE, LINE_HEIGHT, LETTER_SPACING, FONT_WEIGHT } from "../config.js";
import { pxToRemToTailwind, numToFixed } from "../utils.js";
import { fillToTailwind } from "../colors.js";

/**
 * Generate text alignment classes
 */
export function textAlignClasses(node: FigmaNode): string[] {
  const classes: string[] = [];

  // Horizontal alignment
  if (node.textAlignHorizontal === "CENTER") {
    classes.push("text-center");
  } else if (node.textAlignHorizontal === "RIGHT") {
    classes.push("text-right");
  } else if (node.textAlignHorizontal === "JUSTIFIED") {
    classes.push("text-justify");
  }

  // Vertical alignment (for flex containers)
  if (node.textAlignVertical === "CENTER") {
    classes.push("justify-center");
  } else if (node.textAlignVertical === "BOTTOM") {
    classes.push("justify-end");
  }

  return classes;
}

/**
 * Generate text style classes from a text segment
 */
export function textStyleClasses(
  segment: TextSegment,
  settings: ConversionSettings
): string[] {
  if (!segment) {
    return [];
  }

  const classes: string[] = [];

  try {
    // Font size
    if (segment.fontSize) {
      classes.push(`text-${pxToRemToTailwind(segment.fontSize, FONT_SIZE, settings)}`);
    }

    // Font weight
    if (segment.fontWeight && FONT_WEIGHT[segment.fontWeight]) {
      classes.push(`font-${FONT_WEIGHT[segment.fontWeight]}`);
    }

    // Font family
    if (segment.fontName?.family) {
      classes.push(`font-['${segment.fontName.family.replace(/\s/g, "_")}']`);
    }

    // Text color
    if (segment.fills && Array.isArray(segment.fills) && segment.fills.length > 0) {
      const color = fillToTailwind(segment.fills, "text", settings);
      if (color) {
        classes.push(color);
      }
    }

    // Line height
    if (segment.lineHeight && segment.lineHeight.unit !== "AUTO") {
      let lineHeightPx = 0;

      if (segment.lineHeight.unit === "PIXELS") {
        lineHeightPx = segment.lineHeight.value || 0;
      } else if (segment.lineHeight.unit === "PERCENT" && segment.fontSize) {
        lineHeightPx = ((segment.lineHeight.value || 0) / 100) * segment.fontSize;
      }

      if (lineHeightPx > 0) {
        classes.push(`leading-${pxToRemToTailwind(lineHeightPx, LINE_HEIGHT, settings)}`);
      }
    }

    // Letter spacing
    if (segment.letterSpacing && segment.letterSpacing.value !== 0) {
      let letterSpacingPx = segment.letterSpacing.value || 0;

      if (segment.letterSpacing.unit === "PERCENT" && segment.fontSize) {
        letterSpacingPx = (letterSpacingPx / 100) * segment.fontSize;
      }

      if (letterSpacingPx !== 0) {
        const lsRem = letterSpacingPx / settings.baseFontSize;
        const lsClass = LETTER_SPACING[lsRem.toString()];
        classes.push(
          lsClass ? `tracking-${lsClass}` : `tracking-[${numToFixed(letterSpacingPx)}px]`
        );
      }
    }

    // Text decoration
    if (segment.textDecoration === "UNDERLINE") {
      classes.push("underline");
    } else if (segment.textDecoration === "STRIKETHROUGH") {
      classes.push("line-through");
    }

    // Text transform
    if (segment.textCase === "UPPER") {
      classes.push("uppercase");
    } else if (segment.textCase === "LOWER") {
      classes.push("lowercase");
    } else if (segment.textCase === "TITLE") {
      classes.push("capitalize");
    }
  } catch {
    // Return whatever we managed to collect
  }

  return classes;
}


