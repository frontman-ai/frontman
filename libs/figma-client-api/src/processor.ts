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
  NodeSkeleton,
  CompactNodeSkeleton,
  DEFAULT_SETTINGS,
} from "./types.js";

// Type declarations for Figma API (when available in plugin context)
declare global {
  interface Window {
    figma?: {
      getNodeByIdAsync?: (nodeId: string) => Promise<FigmaNode | null>;
    };
  }
}
import { DEFAULT_SETTINGS as defaultSettings } from "./types.js";
import {
  isLikelyIcon,
  isVectorOnlyContainer,
  hasImageFill,
  hasSvgChildren,
  ICON_TYPES,
} from "./detection.js";
import { safeGenerateTailwindClasses, textStyleClasses } from "./tailwind/index.js";
import { uint8ToBase64, estimateNodeTokenCount } from "./utils.js";
import { skeletonToDSL, type DSLConversionOptions } from "./dsl.js";

// Vector types that need special handling
const VECTOR_TYPES = new Set(["VECTOR", "BOOLEAN_OPERATION", "LINE", "STAR", "POLYGON"]);

/**
 * Calculate self token count for a ConvertedNode (excluding children)
 * Should be called before children are added to the node
 * Uses efficient estimation that avoids serializing large binary data
 */
function calculateSelfTokenCount(node: ConvertedNode): number {
  // Use optimized function that doesn't serialize large binary data
  return estimateNodeTokenCount(node);
}

/**
 * Calculate total token count for a ConvertedNode (including all descendants)
 * Should be called after children are processed and added to the node
 */
function calculateTotalTokenCount(node: ConvertedNode, selfTokenCount: number): number {
  // Calculate total token count (node with all descendants)
  let childrenTokenCount = 0;
  if (node.children && node.children.length > 0) {
    childrenTokenCount = node.children.reduce(
      (sum, child) => sum + (child.totalTokenCount || 0),
      0
    );
  }
  return selfTokenCount + childrenTokenCount;
}

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
    const result: ConvertedNode = {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: baseClasses,
      textContent: node.characters || "",
    };
    const selfTokenCount = calculateSelfTokenCount(result);
    result.selfTokenCount = selfTokenCount;
    result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
    return result;
  }

  // No segments - return basic text
  if (segments.length === 0) {
    const result: ConvertedNode = {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: baseClasses,
      textContent: node.characters || "",
    };
    const selfTokenCount = calculateSelfTokenCount(result);
    result.selfTokenCount = selfTokenCount;
    result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
    return result;
  }

  // Single segment - merge classes
  if (segments.length === 1) {
    const segClasses = textStyleClasses(segments[0], settings);
    const result: ConvertedNode = {
      id: node.id,
      name: node.name,
      type: "TEXT",
      tailwind: [baseClasses, ...segClasses].filter(Boolean).join(" "),
      textContent: (segments[0].characters || "").replace(/\n/g, "<br/>"),
    };
    const selfTokenCount = calculateSelfTokenCount(result);
    result.selfTokenCount = selfTokenCount;
    result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
    return result;
  }

  // Multiple segments - return as array
  const textSpans: TextSpan[] = segments.map((s) => ({
    text: (s.characters || "").replace(/\n/g, "<br/>"),
    tailwind: textStyleClasses(s, settings).join(" "),
  }));

  const result: ConvertedNode = {
    id: node.id,
    name: node.name,
    type: "TEXT",
    tailwind: baseClasses,
    textContent: textSpans,
  };
  const selfTokenCount = calculateSelfTokenCount(result);
  result.selfTokenCount = selfTokenCount;
  result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
  return result;
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
          // Skip transforms for SVG nodes - Figma SVG export already bakes in rotation and position
          const tailwind = safeGenerateTailwindClasses(node, settings, true);
          const result: ConvertedNode = { id: node.id, name: node.name, type: "SVG", tailwind, svg };
          const selfTokenCount = calculateSelfTokenCount(result);
          result.selfTokenCount = selfTokenCount;
          result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
          return result;
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
          // Skip transforms for SVG nodes - Figma SVG export already bakes in rotation and position
          const tailwind = safeGenerateTailwindClasses(node, settings, true);
          const result: ConvertedNode = { id: node.id, name: node.name, type: "SVG", tailwind, svg };
          const selfTokenCount = calculateSelfTokenCount(result);
          result.selfTokenCount = selfTokenCount;
          result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
          return result;
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
      const result: ConvertedNode = {
        id: node.id,
        name: node.name,
        type: "VECTOR_FAILED",
        tailwind,
        warning: "Vector export failed - needs manual SVG",
      };
      const selfTokenCount = calculateSelfTokenCount(result);
      result.selfTokenCount = selfTokenCount;
      result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
      return result;
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
      const result: ConvertedNode = {
        id: node.id,
        name: node.name,
        type: "TEXT",
        tailwind: "",
        textContent: node.characters || "",
      };
      const selfTokenCount = calculateSelfTokenCount(result);
      result.selfTokenCount = selfTokenCount;
      result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
      return result;
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

        // Calculate self token count before adding children
        const selfTokenCount = calculateSelfTokenCount(result);
        result.selfTokenCount = selfTokenCount;

        // Process children if any
        if (settings.withChildren && node.children && node.children.length > 0) {
          const childResults = await Promise.all(
            node.children.map((c) => processNode(c, settings))
          );
          result.children = childResults.filter(
            (c): c is ConvertedNode => c !== null
          );
        }

        // Calculate total token count after children are added
        result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
        return result;
      }
    } catch {
      // Fall through to process as normal node
    }
  }

  // Standard nodes
  // If this is a container with SVG children, skip transforms (SVG export bakes them in)
  const skipTransforms = hasSvgChildren(node, settings);
  const tailwind = safeGenerateTailwindClasses(node, settings, skipTransforms);
  const result: ConvertedNode = {
    id: node.id,
    name: node.name,
    type: node.type,
    tailwind,
  };

  // Calculate self token count before adding children
  const selfTokenCount = calculateSelfTokenCount(result);
  result.selfTokenCount = selfTokenCount;

  // Process children
  if (settings.withChildren && node.children && node.children.length > 0) {
    const childResults = await Promise.all(
      node.children.map((c) => processNode(c, settings))
    );
    result.children = childResults.filter(
      (c): c is ConvertedNode => c !== null
    );
  }

  // Calculate total token count after children are added
  result.totalTokenCount = calculateTotalTokenCount(result, selfTokenCount);
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

// ============================================================================
// Skeleton Processing (Lightweight Overview)
// ============================================================================

/**
 * Estimate what a ConvertedNode would contain and calculate its token count
 * This simulates the conversion process without doing expensive operations
 * (like SVG/image exports) to get accurate token estimates
 */
function estimateConvertedNodeTokenCount(
  node: FigmaNode,
  settings: ConversionSettings
): number {
  // Create a mock ConvertedNode structure to estimate tokens accurately
  const mockConverted: {
    id: string;
    name: string;
    type: string;
    tailwind: string;
    textContent?: string | Array<{ text: string; tailwind: string }>;
    svg?: string;
    imageBase64?: string;
    warning?: string;
  } = {
    id: node.id,
    name: node.name,
    type: node.type,
    tailwind: "", // Will be estimated
  };

  // Generate tailwind classes (this is fast, no async operations)
  try {
    mockConverted.tailwind = safeGenerateTailwindClasses(node, settings);
  } catch {
    mockConverted.tailwind = "";
  }

  // Estimate what additional properties would be included
  if (node.type === "TEXT") {
    // Text nodes would have textContent
    if (node.characters) {
      mockConverted.textContent = node.characters;
    }
  }

  // Estimate if this would be an SVG node (without actually exporting)
  const shouldBeSvg =
    settings.embedVectors &&
    ((isLikelyIcon(node, settings) || VECTOR_TYPES.has(node.type)) ||
      isVectorOnlyContainer(node));

  if (shouldBeSvg) {
    // Estimate SVG size based on node dimensions and complexity
    // Typical SVG is roughly: viewBox + paths, can be 500-5000 chars for simple icons
    const estimatedSvgSize = node.width && node.height
      ? Math.max(500, (node.width + node.height) * 2)
      : 1000;
    mockConverted.svg = "x".repeat(estimatedSvgSize); // Placeholder for estimation
  }

  // Estimate if this would be an image node (without actually exporting)
  if (settings.embedImages && node.fills && hasImageFill(node.fills)) {
    // Base64 images are large - estimate character count based on dimensions
    // Raw image: width * height * 4 bytes (RGBA)
    // Base64 overhead: ~33% larger than raw bytes
    // We estimate character count, then estimateNodeTokenCount divides by 5 for tokens
    const estimatedImageSize = node.width && node.height
      ? Math.ceil(node.width * node.height * 4 * 1.33)
      : 50000; // Default estimate for images (characters)
    mockConverted.imageBase64 = "x".repeat(estimatedImageSize); // Placeholder for estimation
  }

  // Use the existing efficient token counting function
  return estimateNodeTokenCount(mockConverted);
}

/**
 * Create a lightweight skeleton of a Figma node tree with compact property names
 * Only includes i (id), n (name), s (selfTokenCount), t (totalTokenCount), c (children)
 * Uses shortened property names to reduce token count significantly for large trees
 * Property mapping: i=id, n=name, s=selfTokenCount, t=totalTokenCount, c=children
 * Used for agentic processes to get an overview before fetching full node data
 */
export async function figmaToTailwindJSONSkeleton(
  node: FigmaNode,
  userSettings: Partial<ConversionSettings> = {}
): Promise<CompactNodeSkeleton | null> {
  const settings: ConversionSettings = { ...defaultSettings, ...userSettings };

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

  // Estimate self token count (this node without children)
  // This simulates what the ConvertedNode would contain
  const selfTokenCount = estimateConvertedNodeTokenCount(node, settings);

  // Process children recursively
  let children: CompactNodeSkeleton[] = [];
  let childrenTokenCount = 0;

  if (settings.withChildren && node.children && node.children.length > 0) {
    const childResults = await Promise.all(
      node.children.map((c) => figmaToTailwindJSONSkeleton(c, userSettings))
    );
    children = childResults.filter(
      (c): c is CompactNodeSkeleton => c !== null
    );
    childrenTokenCount = children.reduce(
      (sum, child) => sum + child.t,
      0
    );
  }

  // Calculate total token count
  const totalTokenCount = selfTokenCount + childrenTokenCount;

  return {
    i: node.id,
    n: node.name,
    s: selfTokenCount,
    t: totalTokenCount,
    c: children.length > 0 ? children : undefined,
  };
}

/**
 * Convert a CompactNodeSkeleton back to full format with full property names
 */
export function expandSkeleton(compact: CompactNodeSkeleton): NodeSkeleton {
  return {
    id: compact.i,
    name: compact.n,
    selfTokenCount: compact.s,
    totalTokenCount: compact.t,
    children: compact.c?.map(expandSkeleton),
  };
}

// ============================================================================
// Node Fetching (for Agentic Processes)
// ============================================================================

/**
 * Fetch a Figma node by ID using the Figma API
 * Requires window.figma.getNodeByIdAsync to be available
 * 
 * @param nodeId - The Figma node ID (e.g., "0:1927")
 * @param options - Optional settings for conversion
 * @returns The converted node or null if not found
 * 
 * @example
 * ```ts
 * const node = await getFigmaNodeJSON("0:1927", { embedVectors: true });
 * ```
 */
export async function getFigmaNodeJSON(
  nodeId: string,
  userSettings: Partial<ConversionSettings> = {}
): Promise<ConvertedNode | null> {
  // Check if we're in a Figma plugin environment
  if (typeof window === "undefined" || !window.figma) {
    throw new Error(
      "getFigmaNodeJSON requires window.figma API. This function must be called from a Figma plugin context."
    );
  }

  if (!window.figma.getNodeByIdAsync) {
    throw new Error(
      "window.figma.getNodeByIdAsync is not available. Make sure you're using a compatible Figma API version."
    );
  }

  try {
    // Fetch the node from Figma
    const node = await window.figma.getNodeByIdAsync(nodeId);

    if (!node) {
      return null;
    }

    // Convert the node using the full conversion process
    const settings: ConversionSettings = { ...defaultSettings, ...userSettings };
    return processNode(node as FigmaNode, settings);
  } catch (error) {
    console.error(`Failed to fetch node ${nodeId}:`, error);
    throw error;
  }
}

// ============================================================================
// DSL Generation (High-Level API)
// ============================================================================

/**
 * Convert a Figma node to a compact DSL string format
 * Combines skeleton extraction with DSL generation
 * 
 * @param node - The Figma node to convert
 * @param conversionSettings - Optional settings for the conversion process
 * @param dslOptions - Optional settings for DSL output formatting
 * @returns DSL string representation of the node tree, or null if node is invalid
 * 
 * @example
 * ```ts
 * const dsl = await figmaToDSL(node, {}, { sourceFile: "pricing.figma" });
 * // Returns:
 * // @source: pricing.figma
 * // pricing(v:8) #0:1927:
 * //   .header(v:3) #0:1930:
 * //     title #0:1932
 * //     ...
 * ```
 */
export async function figmaToDSL(
  node: FigmaNode,
  conversionSettings: Partial<ConversionSettings> = {},
  dslOptions: DSLConversionOptions = {}
): Promise<string | null> {
  const skeleton = await figmaToTailwindJSONSkeleton(node, conversionSettings);
  
  if (!skeleton) {
    return null;
  }
  
  return skeletonToDSL(skeleton, dslOptions);
}
