/**
 * Node Processor
 * Main processing logic for converting Figma nodes to Tailwind JSON
 */

import type {
  FigmaNode,
  TextSegment,
  ConversionSettings,
  ConvertedNode,
  TextSpan,
  DEFAULT_SETTINGS,
} from "./types.js";
import { DEFAULT_SETTINGS as defaultSettings } from "./types.js";
import {
  isLikelyIcon,
  isVectorOnlyContainer,
  hasImageFill,
  ICON_TYPES,
} from "./detection.js";
import { safeGenerateTailwindClasses, textStyleClasses } from "./tailwind/index.js";
import { uint8ToBase64 } from "./utils.js";

// Vector types that need special handling
const VECTOR_TYPES = new Set(["VECTOR", "BOOLEAN_OPERATION", "LINE", "STAR", "POLYGON"]);

/**
 * Process a text node and extract styled segments
 */
export async function processTextNode(
  node: FigmaNode,
  settings: ConversionSettings
): Promise<ConvertedNode> {
  const baseClasses = safeGenerateTailwindClasses(node, settings);

  let segments: TextSegment[] = [];
  try {
    if (node.getStyledTextSegments) {
      segments = node.getStyledTextSegments([
        "fontName",
        "fills",
        "fontSize",
        "fontWeight",
        "letterSpacing",
        "lineHeight",
        "textCase",
        "textDecoration",
      ]) || [];
    }
  } catch {
    // If getStyledTextSegments fails, return basic text node
    return {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: baseClasses,
      textContent: node.characters || "",
    };
  }

  // No segments - return basic text
  if (segments.length === 0) {
    return {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: baseClasses,
      textContent: node.characters || "",
    };
  }

  // Single segment - merge classes
  if (segments.length === 1) {
    const segClasses = textStyleClasses(segments[0], settings);
    return {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: [baseClasses, ...segClasses].filter(Boolean).join(" "),
      textContent: (segments[0].characters || "").replace(/\n/g, "<br/>"),
    };
  }

  // Multiple segments - return as array
  const textSpans: TextSpan[] = segments.map((s) => ({
    text: (s.characters || "").replace(/\n/g, "<br/>"),
    tailwind: textStyleClasses(s, settings).join(" "),
  }));

  return {
    id: node.id,
    name: node.name,
    type: "TEXT",
    tailwind: baseClasses,
    textContent: textSpans,
  };
}

/**
 * Process a single Figma node recursively
 */
export async function processNode(
  node: FigmaNode,
  settings: ConversionSettings = defaultSettings
): Promise<ConvertedNode | null> {
  // Skip invisible nodes
  if (node.visible === false) {
    return null;
  }

  // Skip nodes with zero dimensions
  if (
    node.width !== undefined &&
    node.height !== undefined &&
    (node.width <= 0 || node.height <= 0)
  ) {
    return null;
  }

  // Check if this is a vector-only container (like a stars background)
  // Export the entire container as a single SVG instead of individual children
  if (settings.embedVectors && isVectorOnlyContainer(node)) {
    try {
      if (node.exportAsync) {
        const svg = await node.exportAsync({ format: "SVG_STRING" }) as string;
        if (svg && svg.length > 0 && !svg.includes('viewBox="0 0 0 0"')) {
          const tailwind = safeGenerateTailwindClasses(node, settings);
          return { id: node.id, name: node.name, type: "SVG", tailwind, svg };
        }
      }
    } catch (e) {
      console.warn(
        `Container SVG export failed for ${node.name}, processing children individually:`,
        e instanceof Error ? e.message : e
      );
      // Fall through to process children individually
    }
  }

  // SVG export for vector-based nodes
  const shouldExportAsSvg =
    settings.embedVectors &&
    (isLikelyIcon(node, settings) || VECTOR_TYPES.has(node.type));

  if (shouldExportAsSvg) {
    try {
      if (node.exportAsync) {
        const svg = await node.exportAsync({ format: "SVG_STRING" }) as string;
        // Only return SVG result if we actually got valid content
        if (svg && svg.length > 0 && !svg.includes('viewBox="0 0 0 0"')) {
          const tailwind = safeGenerateTailwindClasses(node, settings);
          return { id: node.id, name: node.name, type: "SVG", tailwind, svg };
        }
      }
    } catch (e) {
      // Log warning for failed vector exports
      console.warn(
        `SVG export failed for ${node.name} (${node.type}):`,
        e instanceof Error ? e.message : e
      );
    }

    // If we're a pure vector type and export failed, still return with warning
    if (VECTOR_TYPES.has(node.type)) {
      const tailwind = safeGenerateTailwindClasses(node, settings);
      return {
        id: node.id,
        name: node.name,
        type: "VECTOR_FAILED",
        tailwind,
        warning: "Vector export failed - needs manual SVG",
      };
    }
  }

  // Text nodes
  if (node.type === "TEXT") {
    try {
      return await processTextNode(node, settings);
    } catch (e) {
      console.warn(
        `Text processing failed for ${node.name}:`,
        e instanceof Error ? e.message : e
      );
      return {
        id: node.id,
        name: node.name,
        type: "TEXT",
        tailwind: "",
        textContent: node.characters || "",
      };
    }
  }

  // Image export
  if (settings.embedImages && node.fills && hasImageFill(node.fills)) {
    try {
      if (node.exportAsync) {
        const bytes = (await node.exportAsync({
          format: "PNG",
          constraint: { type: "SCALE", value: 1 },
        })) as Uint8Array;

        const tailwind = safeGenerateTailwindClasses(node, settings);
        const result: ConvertedNode = {
          id: node.id,
          name: node.name,
          type: "IMAGE",
          tailwind,
          imageBase64: uint8ToBase64(bytes),
        };

        // Process children if any
        if (node.children && node.children.length > 0) {
          const childResults = await Promise.all(
            node.children.map((c) => processNode(c, settings))
          );
          result.children = childResults.filter(
            (c): c is ConvertedNode => c !== null
          );
        }

        return result;
      }
    } catch {
      // Fall through to process as normal node
    }
  }

  // Standard nodes
  const tailwind = safeGenerateTailwindClasses(node, settings);
  const result: ConvertedNode = {
    id: node.id,
    name: node.name,
    type: node.type,
    tailwind,
  };

  // Process children
  if (node.children && node.children.length > 0) {
    const childResults = await Promise.all(
      node.children.map((c) => processNode(c, settings))
    );
    result.children = childResults.filter(
      (c): c is ConvertedNode => c !== null
    );
  }

  return result;
}

/**
 * Convert a Figma node to Tailwind JSON
 */
export async function figmaToTailwindJSON(
  node: FigmaNode,
  userSettings: Partial<ConversionSettings> = {}
): Promise<ConvertedNode | null> {
  const settings: ConversionSettings = { ...defaultSettings, ...userSettings };
  return processNode(node, settings);
}

/**
 * Convert multiple Figma nodes to Tailwind JSON
 */
export async function convertNodes(
  nodes: FigmaNode[],
  userSettings: Partial<ConversionSettings> = {}
): Promise<ConvertedNode[]> {
  const settings: ConversionSettings = { ...defaultSettings, ...userSettings };
  const results = await Promise.all(nodes.map((n) => processNode(n, settings)));
  return results.filter((r): r is ConvertedNode => r !== null);
}
