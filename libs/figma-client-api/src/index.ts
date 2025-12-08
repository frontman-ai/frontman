/**
 * Figma Client API
 * 
 * Figma Node to Tailwind JSON Converter
 * 
 * This library provides modular, testable functions for converting
 * Figma design nodes to Tailwind CSS classes.
 * 
 * @example
 * ```ts
 * import { figmaToTailwindJSON, convertNodes } from '@ask-the-llm/figma-client-api';
 * 
 * // Convert a single node
 * const result = await figmaToTailwindJSON(node, { embedVectors: true });
 * 
 * // Convert multiple nodes
 * const results = await convertNodes(nodes, { embedImages: false });
 * ```
 */

// Types
export type {
  ConversionSettings,
  FigmaNode,
  FigmaNodeType,
  ConvertedNode,
  TextSpan,
  TextSegment,
  Paint,
  Effect,
  RGB,
  RGBA,
  Vector2D,
  GradientStop,
  LayoutMode,
  LayoutSizing,
  LayoutPositioning,
  PrimaryAxisAlign,
  CounterAxisAlign,
  TextAlign,
  TextVerticalAlign,
  FontName,
  LineHeight,
  LetterSpacing,
  TextDecoration,
  TextCase,
  ExportSetting,
} from "./types.js";

export { DEFAULT_SETTINGS, MIXED } from "./types.js";

// Configuration
export {
  LAYOUT_SIZE,
  BORDER_RADIUS,
  FONT_SIZE,
  LINE_HEIGHT,
  LETTER_SPACING,
  BLUR,
  OPACITY_VALUES,
  FONT_WEIGHT,
  COLOR_MAP,
  ROTATION_VALUES,
  GRADIENT_DIRECTIONS,
  GRADIENT_ANGLES,
  BLEND_MODES,
} from "./config.js";

// Utilities
export {
  numToFixed,
  nearestValue,
  exactValue,
  nearestWithThreshold,
  pxToRemToTailwind,
  pxToTailwind,
  pxToLayoutSize,
  pxToBorderRadius,
  pxToFontSize,
  pxToLineHeight,
  pxToBlur,
  rgbToHex,
  hexToRgb,
  colorDistance,
  nearestColorName,
  nearestOpacity,
  uint8ToBase64,
} from "./utils.js";

// Detection
export {
  ICON_TYPES,
  CONTAINER_TYPES,
  DISALLOWED_TYPES,
  SKIP_FILL_TYPES,
  hasTextDescendant,
  isLikelyIcon,
  isVectorOnlyContainer,
  hasImageFill,
  retrieveTopFill,
  needsAbsolutePositioning,
  needsRelativePositioning,
} from "./detection.js";

// Colors
export {
  colorToTailwind,
  linearGradientToTailwind,
  fillToTailwind,
} from "./colors.js";

// Tailwind Generators
export {
  generateTailwindClasses,
  safeGenerateTailwindClasses,
  sizeClasses,
  paddingClasses,
  autoLayoutClasses,
  overflowClasses,
  borderRadiusClasses,
  borderClasses,
  shadowClasses,
  blendClasses,
  positionClasses,
  textAlignClasses,
  textStyleClasses,
} from "./tailwind/index.js";

// Processor (main entry points)
export {
  processTextNode,
  processNode,
  figmaToTailwindJSON,
  convertNodes,
} from "./processor.js";
