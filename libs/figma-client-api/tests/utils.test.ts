import { describe, it, expect } from "vitest";
import {
  numToFixed,
  nearestValue,
  exactValue,
  nearestWithThreshold,
  rgbToHex,
  hexToRgb,
  colorDistance,
  nearestColorName,
  nearestOpacity,
  pxToLayoutSize,
  pxToRemToTailwind,
} from "../src/utils.js";
import { DEFAULT_SETTINGS } from "../src/types.js";
import { LAYOUT_SIZE, FONT_SIZE } from "../src/config.js";

describe("numToFixed", () => {
  it("should return integer as string without decimals", () => {
    expect(numToFixed(42)).toBe("42");
    expect(numToFixed(0)).toBe("0");
    expect(numToFixed(100)).toBe("100");
  });

  it("should format decimals up to 2 places", () => {
    expect(numToFixed(3.14159)).toBe("3.14");
    expect(numToFixed(2.5)).toBe("2.5");
    expect(numToFixed(1.10)).toBe("1.1");
  });

  it("should remove trailing zeros", () => {
    expect(numToFixed(3.00)).toBe("3");
    expect(numToFixed(2.50)).toBe("2.5");
    expect(numToFixed(1.20)).toBe("1.2");
  });
});

describe("nearestValue", () => {
  it("should find the nearest value in array", () => {
    const arr = [0, 10, 20, 30, 40, 50];
    expect(nearestValue(12, arr)).toBe(10);
    expect(nearestValue(27, arr)).toBe(30);
    expect(nearestValue(0, arr)).toBe(0);
    expect(nearestValue(50, arr)).toBe(50);
  });

  it("should handle arrays with single value", () => {
    expect(nearestValue(42, [10])).toBe(10);
  });

  it("should prefer first match when equidistant", () => {
    expect(nearestValue(15, [10, 20])).toBe(10);
  });
});

describe("exactValue", () => {
  it("should find exact match within tolerance", () => {
    const arr = [0, 0.25, 0.5, 1];
    expect(exactValue(0.25, arr)).toBe(0.25);
    expect(exactValue(0.26, arr)).toBe(0.25); // Within 0.05 tolerance
    expect(exactValue(0.24, arr)).toBe(0.25);
  });

  it("should return null when no match within tolerance", () => {
    const arr = [0, 1, 2];
    expect(exactValue(0.5, arr)).toBe(null);
  });
});

describe("nearestWithThreshold", () => {
  it("should return nearest within threshold percentage", () => {
    const arr = [10, 20, 30];
    expect(nearestWithThreshold(11, arr, 15)).toBe(10); // 10% diff
    expect(nearestWithThreshold(22, arr, 15)).toBe(20); // 10% diff
  });

  it("should return null when outside threshold", () => {
    const arr = [10, 20, 30];
    expect(nearestWithThreshold(15, arr, 10)).toBe(null); // 50% diff from 10
  });
});

describe("rgbToHex", () => {
  it("should convert RGB (0-1) to hex", () => {
    expect(rgbToHex({ r: 0, g: 0, b: 0 })).toBe("#000000");
    expect(rgbToHex({ r: 1, g: 1, b: 1 })).toBe("#ffffff");
    expect(rgbToHex({ r: 1, g: 0, b: 0 })).toBe("#ff0000");
    expect(rgbToHex({ r: 0, g: 1, b: 0 })).toBe("#00ff00");
    expect(rgbToHex({ r: 0, g: 0, b: 1 })).toBe("#0000ff");
  });

  it("should handle fractional values", () => {
    expect(rgbToHex({ r: 0.5, g: 0.5, b: 0.5 })).toBe("#808080");
  });
});

describe("hexToRgb", () => {
  it("should parse hex to RGB (0-255)", () => {
    expect(hexToRgb("#000000")).toEqual({ r: 0, g: 0, b: 0 });
    expect(hexToRgb("#ffffff")).toEqual({ r: 255, g: 255, b: 255 });
    expect(hexToRgb("#ff0000")).toEqual({ r: 255, g: 0, b: 0 });
  });
});

describe("colorDistance", () => {
  it("should calculate Euclidean distance between colors", () => {
    const black = { r: 0, g: 0, b: 0 };
    const white = { r: 255, g: 255, b: 255 };
    const red = { r: 255, g: 0, b: 0 };

    expect(colorDistance(black, black)).toBe(0);
    expect(colorDistance(black, white)).toBeCloseTo(441.67, 1);
    expect(colorDistance(black, red)).toBe(255);
  });
});

describe("nearestColorName", () => {
  it("should return exact Tailwind color names", () => {
    expect(nearestColorName("#000000", true)).toBe("black");
    expect(nearestColorName("#ffffff", true)).toBe("white");
    expect(nearestColorName("#ef4444", true)).toBe("red-500");
    expect(nearestColorName("#3b82f6", true)).toBe("blue-500");
  });

  it("should return arbitrary value when rounding disabled", () => {
    expect(nearestColorName("#123456", false)).toBe("[#123456]");
  });

  it("should find nearest color when rounding enabled", () => {
    // Slightly off from red-500 (#ef4444)
    const result = nearestColorName("#ef4445", true);
    expect(result).toBe("red-500");
  });
});

describe("nearestOpacity", () => {
  it("should find nearest Tailwind opacity value", () => {
    expect(nearestOpacity(1)).toBe(100);
    expect(nearestOpacity(0.5)).toBe(50);
    expect(nearestOpacity(0)).toBe(0);
    expect(nearestOpacity(0.72)).toBe(70);
    expect(nearestOpacity(0.77)).toBe(75);
  });
});

describe("pxToLayoutSize", () => {
  it("should convert px to Tailwind size suffix", () => {
    expect(pxToLayoutSize(0, DEFAULT_SETTINGS)).toBe("0");
    expect(pxToLayoutSize(4, DEFAULT_SETTINGS)).toBe("1");
    expect(pxToLayoutSize(16, DEFAULT_SETTINGS)).toBe("4");
    expect(pxToLayoutSize(64, DEFAULT_SETTINGS)).toBe("16");
  });

  it("should return arbitrary value for non-standard sizes", () => {
    // With 15% threshold, most values get rounded to nearest Tailwind value
    // We need values that are >15% away from any standard value
    // The largest standard is 384px (96), so 500px should be arbitrary
    expect(pxToLayoutSize(500, DEFAULT_SETTINGS)).toBe("[500px]");
    expect(pxToLayoutSize(1000, DEFAULT_SETTINGS)).toBe("[1000px]");
  });
});

describe("pxToRemToTailwind", () => {
  it("should convert px to rem-based Tailwind suffix", () => {
    // Font sizes: 16px base
    expect(pxToRemToTailwind(16, FONT_SIZE, DEFAULT_SETTINGS)).toBe("base"); // 1rem
    expect(pxToRemToTailwind(12, FONT_SIZE, DEFAULT_SETTINGS)).toBe("xs"); // 0.75rem
    expect(pxToRemToTailwind(14, FONT_SIZE, DEFAULT_SETTINGS)).toBe("sm"); // 0.875rem
  });
});


