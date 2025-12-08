import { describe, it, expect } from "vitest";
import {
  colorToTailwind,
  fillToTailwind,
  linearGradientToTailwind,
} from "../src/colors.js";
import { DEFAULT_SETTINGS } from "../src/types.js";
import type { Paint } from "../src/types.js";

describe("colorToTailwind", () => {
  it("should handle black color", () => {
    const result = colorToTailwind(
      { r: 0, g: 0, b: 0 },
      "bg",
      undefined,
      DEFAULT_SETTINGS
    );
    expect(result).toBe("bg-black");
  });

  it("should handle white color", () => {
    const result = colorToTailwind(
      { r: 1, g: 1, b: 1 },
      "bg",
      undefined,
      DEFAULT_SETTINGS
    );
    expect(result).toBe("bg-white");
  });

  it("should handle colors with opacity", () => {
    const result = colorToTailwind(
      { r: 0, g: 0, b: 0 },
      "bg",
      0.5,
      DEFAULT_SETTINGS
    );
    expect(result).toBe("bg-black/50");
  });

  it("should convert Tailwind colors", () => {
    // red-500 is #ef4444
    const result = colorToTailwind(
      { r: 0xef / 255, g: 0x44 / 255, b: 0x44 / 255 },
      "text",
      undefined,
      DEFAULT_SETTINGS
    );
    expect(result).toBe("text-red-500");
  });

  it("should use different prefixes", () => {
    expect(
      colorToTailwind({ r: 0, g: 0, b: 0 }, "border", undefined, DEFAULT_SETTINGS)
    ).toBe("border-black");
    expect(
      colorToTailwind({ r: 0, g: 0, b: 0 }, "text", undefined, DEFAULT_SETTINGS)
    ).toBe("text-black");
  });
});

describe("fillToTailwind", () => {
  it("should return empty string for undefined fills", () => {
    expect(fillToTailwind(undefined, "bg", DEFAULT_SETTINGS)).toBe("");
  });

  it("should return empty string for empty fills array", () => {
    expect(fillToTailwind([], "bg", DEFAULT_SETTINGS)).toBe("");
  });

  it("should handle solid fills", () => {
    const fills: Paint[] = [
      {
        type: "SOLID",
        visible: true,
        color: { r: 0, g: 0, b: 0 },
      },
    ];
    expect(fillToTailwind(fills, "bg", DEFAULT_SETTINGS)).toBe("bg-black");
  });

  it("should use topmost visible fill", () => {
    const fills: Paint[] = [
      { type: "SOLID", visible: true, color: { r: 1, g: 0, b: 0 } },
      { type: "SOLID", visible: true, color: { r: 0, g: 0, b: 0 } },
    ];
    // Last visible fill should be used (reversed)
    expect(fillToTailwind(fills, "bg", DEFAULT_SETTINGS)).toBe("bg-black");
  });

  it("should skip invisible fills", () => {
    const fills: Paint[] = [
      { type: "SOLID", visible: true, color: { r: 1, g: 0, b: 0 } },
      { type: "SOLID", visible: false, color: { r: 0, g: 0, b: 0 } },
    ];
    expect(fillToTailwind(fills, "bg", DEFAULT_SETTINGS)).toBe("bg-[#ff0000]");
  });

  it("should handle solid fill with opacity", () => {
    const fills: Paint[] = [
      {
        type: "SOLID",
        visible: true,
        color: { r: 1, g: 1, b: 1 },
        opacity: 0.5,
      },
    ];
    expect(fillToTailwind(fills, "bg", DEFAULT_SETTINGS)).toBe("bg-white/50");
  });
});

describe("linearGradientToTailwind", () => {
  it("should handle basic linear gradient", () => {
    const fill: Paint = {
      type: "GRADIENT_LINEAR",
      gradientStops: [
        { position: 0, color: { r: 0, g: 0, b: 0, a: 1 } },
        { position: 1, color: { r: 1, g: 1, b: 1, a: 1 } },
      ],
      gradientHandlePositions: [
        { x: 0, y: 0.5 },
        { x: 1, y: 0.5 },
      ],
    };
    const result = linearGradientToTailwind(fill, DEFAULT_SETTINGS);
    expect(result).toBe("bg-gradient-to-r from-black to-white");
  });

  it("should handle vertical gradient", () => {
    const fill: Paint = {
      type: "GRADIENT_LINEAR",
      gradientStops: [
        { position: 0, color: { r: 0, g: 0, b: 0, a: 1 } },
        { position: 1, color: { r: 1, g: 1, b: 1, a: 1 } },
      ],
      gradientHandlePositions: [
        { x: 0.5, y: 0 },
        { x: 0.5, y: 1 },
      ],
    };
    const result = linearGradientToTailwind(fill, DEFAULT_SETTINGS);
    expect(result).toBe("bg-gradient-to-b from-black to-white");
  });

  it("should handle 3-stop gradient with via color", () => {
    const fill: Paint = {
      type: "GRADIENT_LINEAR",
      gradientStops: [
        { position: 0, color: { r: 0, g: 0, b: 0, a: 1 } },
        { position: 0.5, color: { r: 0.5, g: 0.5, b: 0.5, a: 1 } },
        { position: 1, color: { r: 1, g: 1, b: 1, a: 1 } },
      ],
      gradientHandlePositions: [
        { x: 0, y: 0.5 },
        { x: 1, y: 0.5 },
      ],
    };
    const result = linearGradientToTailwind(fill, DEFAULT_SETTINGS);
    expect(result).toContain("via-");
  });

  it("should return empty string for invalid gradient", () => {
    const fill: Paint = {
      type: "GRADIENT_LINEAR",
      gradientStops: [],
    };
    expect(linearGradientToTailwind(fill, DEFAULT_SETTINGS)).toBe("");
  });
});


