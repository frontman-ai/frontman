/**
 * Figma Client API
 * 
 * Figma Node to Tailwind JSON and DSL Converter
 * 
 * @example
 * ```ts
 * import { getFigmaNodeJSON, figmaToDSL } from '@ask-the-llm/figma-client-api';
 * 
 * // Get full JSON for a node by ID
 * const json = await getFigmaNodeJSON("0:1927", { embedVectors: true });
 * 
 * // Convert a Figma node to compact DSL
 * const dsl = await figmaToDSL(node, {}, { sourceFile: "pricing.figma" });
 * ```
 */

// Types needed for API consumers
export type {
  ConversionSettings,
  FigmaNode,
  ConvertedNode,
} from "./types.js";

export type { DSLConversionOptions } from "./dsl.js";

// Main API functions
export { getFigmaNodeJSON, figmaToDSL } from "./processor.js";
