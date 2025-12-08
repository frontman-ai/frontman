/**
 * Tailwind Configuration Mappings
 * Maps pixel/rem values to Tailwind class suffixes
 */

/** Layout size mapping (px to Tailwind suffix) */
export const LAYOUT_SIZE: Record<number, string> = {
  0: "0",
  1: "px",
  2: "0.5",
  4: "1",
  6: "1.5",
  8: "2",
  10: "2.5",
  12: "3",
  14: "3.5",
  16: "4",
  20: "5",
  24: "6",
  28: "7",
  32: "8",
  36: "9",
  40: "10",
  44: "11",
  48: "12",
  56: "14",
  64: "16",
  80: "20",
  96: "24",
  112: "28",
  128: "32",
  144: "36",
  160: "40",
  176: "44",
  192: "48",
  208: "52",
  224: "56",
  240: "60",
  256: "64",
  288: "72",
  320: "80",
  384: "96",
};

/** Border radius mapping (rem to Tailwind suffix) */
export const BORDER_RADIUS: Record<number, string> = {
  0: "none",
  0.125: "sm",
  0.25: "",
  0.375: "md",
  0.5: "lg",
  0.75: "xl",
  1.0: "2xl",
  1.5: "3xl",
  10: "full",
};

/** Font size mapping (rem to Tailwind suffix) */
export const FONT_SIZE: Record<number, string> = {
  0.75: "xs",
  0.875: "sm",
  1: "base",
  1.125: "lg",
  1.25: "xl",
  1.5: "2xl",
  1.875: "3xl",
  2.25: "4xl",
  3: "5xl",
  3.75: "6xl",
  4.5: "7xl",
  6: "8xl",
  8: "9xl",
};

/** Line height mapping (rem to Tailwind suffix) */
export const LINE_HEIGHT: Record<number, string> = {
  0.75: "3",
  1: "4",
  1.25: "5",
  1.5: "6",
  1.75: "7",
  2: "8",
  2.25: "9",
  2.5: "10",
};

/** Letter spacing mapping (em to Tailwind suffix) */
export const LETTER_SPACING: Record<string, string> = {
  "-0.05": "tighter",
  "-0.025": "tight",
  "0.025": "wide",
  "0.05": "wider",
  "0.1": "widest",
};

/** Blur mapping (px to Tailwind suffix) */
export const BLUR: Record<number, string> = {
  0: "none",
  4: "sm",
  8: "",
  12: "md",
  16: "lg",
  24: "xl",
  40: "2xl",
  64: "3xl",
};

/** Opacity values */
export const OPACITY_VALUES = [
  0, 5, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 95, 100,
];

/** Font weight mapping */
export const FONT_WEIGHT: Record<number, string> = {
  100: "thin",
  200: "extralight",
  300: "light",
  400: "normal",
  500: "medium",
  600: "semibold",
  700: "bold",
  800: "extrabold",
  900: "black",
};

/** Tailwind color mapping (hex to color name) */
export const COLOR_MAP: Record<string, string> = {
  "#000000": "black",
  "#ffffff": "white",
  // Slate
  "#f8fafc": "slate-50",
  "#f1f5f9": "slate-100",
  "#e2e8f0": "slate-200",
  "#cbd5e1": "slate-300",
  "#94a3b8": "slate-400",
  "#64748b": "slate-500",
  "#475569": "slate-600",
  "#334155": "slate-700",
  "#1e293b": "slate-800",
  "#0f172a": "slate-900",
  "#020617": "slate-950",
  // Gray
  "#f9fafb": "gray-50",
  "#f3f4f6": "gray-100",
  "#e5e7eb": "gray-200",
  "#d1d5db": "gray-300",
  "#9ca3af": "gray-400",
  "#6b7280": "gray-500",
  "#4b5563": "gray-600",
  "#374151": "gray-700",
  "#1f2937": "gray-800",
  "#111827": "gray-900",
  "#030712": "gray-950",
  // Red
  "#fef2f2": "red-50",
  "#fee2e2": "red-100",
  "#fecaca": "red-200",
  "#fca5a5": "red-300",
  "#f87171": "red-400",
  "#ef4444": "red-500",
  "#dc2626": "red-600",
  "#b91c1c": "red-700",
  "#991b1b": "red-800",
  "#7f1d1d": "red-900",
  "#450a0a": "red-950",
  // Orange
  "#fff7ed": "orange-50",
  "#ffedd5": "orange-100",
  "#fed7aa": "orange-200",
  "#fdba74": "orange-300",
  "#fb923c": "orange-400",
  "#f97316": "orange-500",
  "#ea580c": "orange-600",
  "#c2410c": "orange-700",
  // Yellow
  "#fefce8": "yellow-50",
  "#fef9c3": "yellow-100",
  "#fef08a": "yellow-200",
  "#fde047": "yellow-300",
  "#facc15": "yellow-400",
  "#eab308": "yellow-500",
  "#ca8a04": "yellow-600",
  "#a16207": "yellow-700",
  // Green
  "#f0fdf4": "green-50",
  "#dcfce7": "green-100",
  "#bbf7d0": "green-200",
  "#86efac": "green-300",
  "#4ade80": "green-400",
  "#22c55e": "green-500",
  "#16a34a": "green-600",
  "#15803d": "green-700",
  "#166534": "green-800",
  "#14532d": "green-900",
  "#052e16": "green-950",
  // Blue
  "#eff6ff": "blue-50",
  "#dbeafe": "blue-100",
  "#bfdbfe": "blue-200",
  "#93c5fd": "blue-300",
  "#60a5fa": "blue-400",
  "#3b82f6": "blue-500",
  "#2563eb": "blue-600",
  "#1d4ed8": "blue-700",
  "#1e40af": "blue-800",
  "#1e3a8a": "blue-900",
  "#172554": "blue-950",
  // Violet
  "#f5f3ff": "violet-50",
  "#ede9fe": "violet-100",
  "#ddd6fe": "violet-200",
  "#c4b5fd": "violet-300",
  "#a78bfa": "violet-400",
  "#8b5cf6": "violet-500",
  "#7c3aed": "violet-600",
  "#6d28d9": "violet-700",
  // Fuchsia
  "#fdf4ff": "fuchsia-50",
  "#fae8ff": "fuchsia-100",
  "#f5d0fe": "fuchsia-200",
  "#f0abfc": "fuchsia-300",
  "#e879f9": "fuchsia-400",
  "#d946ef": "fuchsia-500",
  "#c026d3": "fuchsia-600",
  "#a21caf": "fuchsia-700",
  // Pink
  "#fdf2f8": "pink-50",
  "#fce7f3": "pink-100",
  "#fbcfe8": "pink-200",
  "#f9a8d4": "pink-300",
  "#f472b6": "pink-400",
  "#ec4899": "pink-500",
  "#db2777": "pink-600",
  "#be185d": "pink-700",
};

/** Rotation values supported by Tailwind */
export const ROTATION_VALUES = [
  -180, -90, -45, -12, -6, -3, -2, -1, 1, 2, 3, 6, 12, 45, 90, 180,
];

/** Gradient direction mapping */
export const GRADIENT_DIRECTIONS: Record<number, string> = {
  0: "bg-gradient-to-r",
  45: "bg-gradient-to-br",
  90: "bg-gradient-to-b",
  135: "bg-gradient-to-bl",
  180: "bg-gradient-to-l",
  "-45": "bg-gradient-to-tr",
  "-90": "bg-gradient-to-t",
  "-135": "bg-gradient-to-tl",
};

/** Gradient direction angles for snapping */
export const GRADIENT_ANGLES = [0, 45, 90, 135, 180, -45, -90, -135, -180];

/** Blend mode mapping */
export const BLEND_MODES: Record<string, string> = {
  MULTIPLY: "mix-blend-multiply",
  SCREEN: "mix-blend-screen",
  OVERLAY: "mix-blend-overlay",
  DARKEN: "mix-blend-darken",
  LIGHTEN: "mix-blend-lighten",
  DIFFERENCE: "mix-blend-difference",
  EXCLUSION: "mix-blend-exclusion",
};


