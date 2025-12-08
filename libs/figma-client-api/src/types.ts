/**
 * Figma Client API Types
 * Type definitions for Figma node conversion to Tailwind
 */

// ============================================================================
// Settings Types
// ============================================================================

export interface ConversionSettings {
  /** Embed SVG content for vector nodes */
  embedVectors: boolean;
  /** Embed base64 images for image nodes */
  embedImages: boolean;
  /** Maximum size (width/height) for icon detection */
  maxIconSize: number;
  /** Include children in results (set false to fetch only the node itself) */
  withChildren: boolean;
  /** Use Tailwind v4 syntax (future-proofing) */
  useTailwind4: boolean;
  /** Round colors to nearest Tailwind color */
  roundTailwindColors: boolean;
  /** Round sizes to nearest Tailwind value */
  roundTailwindValues: boolean;
  /** Base font size for rem calculations (default: 16) */
  baseFontSize: number;
  /** Threshold percentage for value rounding */
  thresholdPercent: number;
}

export const DEFAULT_SETTINGS: ConversionSettings = {
  embedVectors: true,
  embedImages: true,
  maxIconSize: 64,
  withChildren: true,
  useTailwind4: false,
  roundTailwindColors: true,
  roundTailwindValues: true,
  baseFontSize: 16,
  thresholdPercent: 15,
};

// ============================================================================
// Figma Node Types (simplified for conversion)
// ============================================================================

export type FigmaNodeType =
  | "FRAME"
  | "GROUP"
  | "COMPONENT"
  | "INSTANCE"
  | "VECTOR"
  | "BOOLEAN_OPERATION"
  | "POLYGON"
  | "STAR"
  | "LINE"
  | "ELLIPSE"
  | "RECTANGLE"
  | "TEXT"
  | "SLICE"
  | "CONNECTOR"
  | "STICKY"
  | "WIDGET"
  | "CODE_BLOCK";

export type LayoutMode = "NONE" | "HORIZONTAL" | "VERTICAL";
export type LayoutSizing = "FIXED" | "HUG" | "FILL";
export type LayoutPositioning = "AUTO" | "ABSOLUTE";
export type PrimaryAxisAlign = "MIN" | "CENTER" | "MAX" | "SPACE_BETWEEN";
export type CounterAxisAlign = "MIN" | "CENTER" | "MAX" | "BASELINE";
export type TextAlign = "LEFT" | "CENTER" | "RIGHT" | "JUSTIFIED";
export type TextVerticalAlign = "TOP" | "CENTER" | "BOTTOM";
export type LayoutWrap = "NO_WRAP" | "WRAP";

export interface RGB {
  r: number;
  g: number;
  b: number;
}

export interface RGBA extends RGB {
  a: number;
}

export interface GradientStop {
  position: number;
  color: RGBA;
}

export interface Vector2D {
  x: number;
  y: number;
}

export type FillType =
  | "SOLID"
  | "GRADIENT_LINEAR"
  | "GRADIENT_RADIAL"
  | "GRADIENT_ANGULAR"
  | "GRADIENT_DIAMOND"
  | "IMAGE"
  | "EMOJI"
  | "VIDEO";

export interface Paint {
  type: FillType;
  visible?: boolean;
  opacity?: number;
  color?: RGB;
  gradientStops?: GradientStop[];
  gradientHandlePositions?: Vector2D[];
  imageRef?: string;
}

export interface Effect {
  type:
    | "DROP_SHADOW"
    | "INNER_SHADOW"
    | "LAYER_BLUR"
    | "BACKGROUND_BLUR";
  visible?: boolean;
  radius?: number;
  spread?: number;
  offset?: Vector2D;
  color?: RGBA;
}

export interface ExportSetting {
  format: "PNG" | "JPG" | "SVG" | "PDF";
  suffix?: string;
  constraint?: { type: string; value: number };
}

export interface LineHeight {
  unit: "AUTO" | "PIXELS" | "PERCENT";
  value?: number;
}

export interface LetterSpacing {
  unit: "PIXELS" | "PERCENT";
  value: number;
}

export interface FontName {
  family: string;
  style: string;
}

export type TextDecoration = "NONE" | "UNDERLINE" | "STRIKETHROUGH";
export type TextCase = "ORIGINAL" | "UPPER" | "LOWER" | "TITLE";

export interface TextSegment {
  start: number;
  end: number;
  characters: string;
  fontName?: FontName;
  fontSize?: number;
  fontWeight?: number;
  fills?: Paint[];
  lineHeight?: LineHeight;
  letterSpacing?: LetterSpacing;
  textDecoration?: TextDecoration;
  textCase?: TextCase;
}

// Mixed value marker (used when properties vary across selection)
export const MIXED = Symbol("figma.mixed");
export type Mixed = typeof MIXED;

/**
 * Simplified Figma node interface for conversion
 * Contains only properties relevant to Tailwind generation
 */
export interface FigmaNode {
  id: string;
  name: string;
  type: FigmaNodeType;
  visible?: boolean;
  parent?: FigmaNode | null;
  children?: FigmaNode[];

  // Dimensions
  width?: number;
  height?: number;
  minWidth?: number;
  maxWidth?: number;
  minHeight?: number;
  maxHeight?: number;

  // Position
  x?: number;
  y?: number;
  rotation?: number;

  // Layout
  layoutMode?: LayoutMode;
  layoutSizingHorizontal?: LayoutSizing;
  layoutSizingVertical?: LayoutSizing;
  layoutPositioning?: LayoutPositioning;
  primaryAxisAlignItems?: PrimaryAxisAlign;
  counterAxisAlignItems?: CounterAxisAlign;
  layoutWrap?: LayoutWrap;
  itemSpacing?: number;
  paddingLeft?: number;
  paddingRight?: number;
  paddingTop?: number;
  paddingBottom?: number;
  clipsContent?: boolean;

  // Appearance
  fills?: Paint[];
  strokes?: Paint[];
  strokeWeight?: number | Mixed;
  strokeTopWeight?: number;
  strokeRightWeight?: number;
  strokeBottomWeight?: number;
  strokeLeftWeight?: number;
  cornerRadius?: number | Mixed;
  topLeftRadius?: number;
  topRightRadius?: number;
  bottomRightRadius?: number;
  bottomLeftRadius?: number;
  effects?: Effect[];
  opacity?: number;
  blendMode?: string;

  // Text-specific
  characters?: string;
  textAlignHorizontal?: TextAlign;
  textAlignVertical?: TextVerticalAlign;

  // Export
  exportSettings?: ExportSetting[];

  // Methods (optional, for runtime Figma plugin)
  getStyledTextSegments?: (properties: string[]) => TextSegment[];
  exportAsync?: (options: { format: string; constraint?: { type: string; value: number } }) => Promise<Uint8Array | string>;
}

// ============================================================================
// Output Types
// ============================================================================

export interface TextSpan {
  text: string;
  tailwind: string;
}

export interface ConvertedNode {
  id: string;
  name: string;
  type: string;
  tailwind: string;
  children?: ConvertedNode[];
  textContent?: string | TextSpan[];
  svg?: string;
  imageBase64?: string;
  warning?: string;
  totalTokenCount?: number;
  selfTokenCount?: number;
}

/**
 * Lightweight skeleton of a ConvertedNode containing only essential metadata
 * Used for agentic processes to get an overview before fetching full node data
 */
export interface NodeSkeleton {
  id: string;
  name: string;
  selfTokenCount: number;
  totalTokenCount: number;
  children?: NodeSkeleton[];
}

/**
 * Compact version of NodeSkeleton with shortened property names
 * Reduces token count significantly for large trees
 * Property mapping: i=id, n=name, s=selfTokenCount, t=totalTokenCount, c=children
 */
export interface CompactNodeSkeleton {
  i: string;
  n: string;
  s: number;
  t: number;
  c?: CompactNodeSkeleton[];
}
