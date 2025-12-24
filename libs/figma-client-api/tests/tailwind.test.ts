import { describe, it, expect } from "vitest";
import {
  generateTailwindClasses,
  sizeClasses,
  paddingClasses,
  autoLayoutClasses,
  borderRadiusClasses,
  borderClasses,
  positionClasses,
  shadowClasses,
  blendClasses,
  textAlignClasses,
} from "../src/tailwind/index.js";
import { DEFAULT_SETTINGS } from "../src/types.js";
import type { FigmaNode, Paint } from "../src/types.js";

// Helper to create a minimal node
function createNode(
  overrides: Partial<FigmaNode> & { type: FigmaNode["type"] }
): FigmaNode {
  return {
    id: "test-node",
    name: "Test Node",
    visible: true,
    ...overrides,
  };
}

describe("sizeClasses", () => {
  it("should generate width and height classes", () => {
    const node = createNode({
      type: "FRAME",
      width: 64,
      height: 32,
    });
    const classes = sizeClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("w-16");
    expect(classes).toContain("h-8");
  });

  it("should handle FILL sizing", () => {
    const parent = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
    });
    const node = createNode({
      type: "FRAME",
      width: 100,
      layoutSizingHorizontal: "FILL",
      parent,
    });
    const classes = sizeClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("flex-1");
  });

  it("should generate min/max constraints", () => {
    const node = createNode({
      type: "FRAME",
      width: 100,
      height: 100,
      minWidth: 50,
      maxWidth: 200,
    });
    const classes = sizeClasses(node, DEFAULT_SETTINGS);
    expect(classes.some((c) => c.startsWith("min-w-"))).toBe(true);
    expect(classes.some((c) => c.startsWith("max-w-"))).toBe(true);
  });
});

describe("paddingClasses", () => {
  it("should generate uniform padding", () => {
    const node = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
      paddingLeft: 16,
      paddingRight: 16,
      paddingTop: 16,
      paddingBottom: 16,
    });
    const classes = paddingClasses(node, DEFAULT_SETTINGS);
    expect(classes).toEqual(["p-4"]);
  });

  it("should generate symmetric padding (px/py)", () => {
    const node = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
      paddingLeft: 16,
      paddingRight: 16,
      paddingTop: 8,
      paddingBottom: 8,
    });
    const classes = paddingClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("px-4");
    expect(classes).toContain("py-2");
  });

  it("should return empty for no layout", () => {
    const node = createNode({
      type: "FRAME",
      paddingLeft: 16,
    });
    const classes = paddingClasses(node, DEFAULT_SETTINGS);
    expect(classes).toEqual([]);
  });
});

describe("autoLayoutClasses", () => {
  it("should generate horizontal flex classes", () => {
    const node = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
      primaryAxisAlignItems: "CENTER",
      counterAxisAlignItems: "CENTER",
      itemSpacing: 8,
    });
    const classes = autoLayoutClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("inline-flex");
    expect(classes).toContain("justify-center");
    expect(classes).toContain("items-center");
    expect(classes).toContain("gap-2");
  });

  it("should generate vertical flex classes", () => {
    const node = createNode({
      type: "FRAME",
      layoutMode: "VERTICAL",
    });
    const classes = autoLayoutClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("flex-col");
  });

  it("should handle justify-between (no gap)", () => {
    const node = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
      primaryAxisAlignItems: "SPACE_BETWEEN",
      itemSpacing: 8,
    });
    const classes = autoLayoutClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("justify-between");
    expect(classes.some((c) => c.startsWith("gap-"))).toBe(false);
  });
});

describe("borderRadiusClasses", () => {
  it("should generate uniform border radius", () => {
    const node = createNode({
      type: "FRAME",
      cornerRadius: 8,
    });
    const classes = borderRadiusClasses(node, DEFAULT_SETTINGS);
    expect(classes).toEqual(["rounded-lg"]);
  });

  it("should generate rounded-full for ellipse", () => {
    const node = createNode({ type: "ELLIPSE" });
    const classes = borderRadiusClasses(node, DEFAULT_SETTINGS);
    expect(classes).toEqual(["rounded-full"]);
  });

  it("should handle individual corner radii", () => {
    const node = createNode({
      type: "FRAME",
      topLeftRadius: 8,
      topRightRadius: 8,
      bottomRightRadius: 0,
      bottomLeftRadius: 0,
    });
    const classes = borderRadiusClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("rounded-tl-lg");
    expect(classes).toContain("rounded-tr-lg");
  });
});

describe("borderClasses", () => {
  it("should generate border width and color", () => {
    const strokes: Paint[] = [
      { type: "SOLID", color: { r: 0, g: 0, b: 0 } },
    ];
    const node = createNode({
      type: "FRAME",
      strokes,
      strokeWeight: 1,
    });
    const classes = borderClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("border");
    expect(classes).toContain("border-black");
  });

  it("should handle individual border widths", () => {
    const strokes: Paint[] = [{ type: "SOLID", color: { r: 0, g: 0, b: 0 } }];
    const node = createNode({
      type: "FRAME",
      strokes,
      strokeTopWeight: 1,
      strokeBottomWeight: 2,
      strokeLeftWeight: 0,
      strokeRightWeight: 0,
    });
    const classes = borderClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("border-t");
    expect(classes).toContain("border-b-2");
  });

  it("should return empty for no strokes", () => {
    const node = createNode({ type: "FRAME" });
    const classes = borderClasses(node, DEFAULT_SETTINGS);
    expect(classes).toEqual([]);
  });
});

describe("positionClasses", () => {
  it("should generate absolute positioning", () => {
    const node = createNode({
      type: "FRAME",
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
    });
    const classes = positionClasses(node);
    expect(classes).toContain("absolute");
    expect(classes).toContain("left-[10px]");
    expect(classes).toContain("top-[20px]");
  });

  it("should generate relative for GROUP", () => {
    const node = createNode({ type: "GROUP" });
    const classes = positionClasses(node);
    expect(classes).toContain("relative");
  });

  it("should use left-0/top-0 for zero position", () => {
    const node = createNode({
      type: "FRAME",
      layoutPositioning: "ABSOLUTE",
      x: 0,
      y: 0,
    });
    const classes = positionClasses(node);
    expect(classes).toContain("left-0");
    expect(classes).toContain("top-0");
  });

  it("should skip x/y coordinates but keep positioning type when skipCoordinateTransforms is true", () => {
    const node = createNode({
      type: "FRAME",
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
    });
    const classes = positionClasses(node, true);
    // Should still contain positioning type
    expect(classes).toContain("absolute");
    // But should not contain x/y coordinate transforms
    expect(classes).not.toContain("left-[10px]");
    expect(classes).not.toContain("top-[20px]");
  });
});

describe("shadowClasses", () => {
  it("should match Tailwind shadow preset", () => {
    const node = createNode({
      type: "FRAME",
      effects: [
        {
          type: "DROP_SHADOW",
          visible: true,
          offset: { x: 0, y: 1 },
          radius: 3,
          spread: 0,
          color: { r: 0, g: 0, b: 0, a: 0.1 },
        },
      ],
    });
    const classes = shadowClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("shadow");
  });

  it("should generate custom shadow", () => {
    const node = createNode({
      type: "FRAME",
      effects: [
        {
          type: "DROP_SHADOW",
          visible: true,
          offset: { x: 5, y: 5 },
          radius: 10,
          spread: 2,
          color: { r: 0, g: 0, b: 0, a: 0.5 },
        },
      ],
    });
    const classes = shadowClasses(node, DEFAULT_SETTINGS);
    expect(classes[0]).toMatch(/shadow-\[.*\]/);
  });

  it("should handle blur effects", () => {
    const node = createNode({
      type: "FRAME",
      effects: [
        { type: "LAYER_BLUR", visible: true, radius: 16 },
      ],
    });
    const classes = shadowClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("blur");
  });

  it("should handle backdrop blur", () => {
    const node = createNode({
      type: "FRAME",
      effects: [
        { type: "BACKGROUND_BLUR", visible: true, radius: 32 },
      ],
    });
    const classes = shadowClasses(node, DEFAULT_SETTINGS);
    expect(classes.some((c) => c.startsWith("backdrop-blur"))).toBe(true);
  });
});

describe("blendClasses", () => {
  it("should generate opacity class", () => {
    const node = createNode({
      type: "FRAME",
      opacity: 0.5,
    });
    const classes = blendClasses(node);
    expect(classes).toContain("opacity-50");
  });

  it("should generate blend mode class", () => {
    const node = createNode({
      type: "FRAME",
      blendMode: "MULTIPLY",
    });
    const classes = blendClasses(node);
    expect(classes).toContain("mix-blend-multiply");
  });

  it("should generate rotation class", () => {
    const node = createNode({
      type: "FRAME",
      rotation: -45,
    });
    const classes = blendClasses(node);
    expect(classes.some((c) => c.includes("rotate-45"))).toBe(true);
  });

  it("should skip rotation when skipRotation is true (for SVG nodes)", () => {
    const node = createNode({
      type: "VECTOR",
      rotation: -45,
    });
    const classes = blendClasses(node, true);
    // Should not contain rotation classes
    expect(classes.some((c) => c.includes("rotate"))).toBe(false);
    expect(classes.some((c) => c.includes("origin-top-left"))).toBe(false);
  });

  it("should still include opacity and blend mode when skipRotation is true", () => {
    const node = createNode({
      type: "VECTOR",
      rotation: -45,
      opacity: 0.5,
      blendMode: "MULTIPLY",
    });
    const classes = blendClasses(node, true);
    // Should not contain rotation
    expect(classes.some((c) => c.includes("rotate"))).toBe(false);
    // But should still contain opacity and blend mode
    expect(classes).toContain("opacity-50");
    expect(classes).toContain("mix-blend-multiply");
  });

  it("should generate invisible class", () => {
    const node = createNode({
      type: "FRAME",
      visible: false,
    });
    const classes = blendClasses(node);
    expect(classes).toContain("invisible");
  });
});

describe("textAlignClasses", () => {
  it("should generate text-center", () => {
    const node = createNode({
      type: "TEXT",
      textAlignHorizontal: "CENTER",
    });
    const classes = textAlignClasses(node);
    expect(classes).toContain("text-center");
  });

  it("should generate text-right", () => {
    const node = createNode({
      type: "TEXT",
      textAlignHorizontal: "RIGHT",
    });
    const classes = textAlignClasses(node);
    expect(classes).toContain("text-right");
  });

  it("should generate vertical alignment", () => {
    const node = createNode({
      type: "TEXT",
      textAlignVertical: "CENTER",
    });
    const classes = textAlignClasses(node);
    expect(classes).toContain("justify-center");
  });
});

describe("generateTailwindClasses", () => {
  it("should combine all classes", () => {
    const node = createNode({
      type: "FRAME",
      width: 64,
      height: 32,
      layoutMode: "HORIZONTAL",
      paddingLeft: 8,
      paddingRight: 8,
      paddingTop: 8,
      paddingBottom: 8,
      cornerRadius: 4,
      fills: [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }],
    });
    const classes = generateTailwindClasses(node, DEFAULT_SETTINGS);
    expect(classes).toContain("w-16");
    expect(classes).toContain("h-8");
    expect(classes).toContain("inline-flex");
    expect(classes).toContain("p-2");
    expect(classes).toContain("rounded");
    expect(classes).toContain("bg-white");
  });

  it("should exclude rotation when skipTransforms is true", () => {
    const node = createNode({
      type: "VECTOR",
      width: 24,
      height: 24,
      rotation: -45,
    });
    const classes = generateTailwindClasses(node, DEFAULT_SETTINGS, true);
    // Should not contain rotation classes
    expect(classes).not.toMatch(/rotate-45/);
    expect(classes).not.toContain("origin-top-left");
    // But should still contain size classes
    expect(classes).toContain("w-6");
    expect(classes).toContain("h-6");
  });

  it("should exclude x/y coordinate transforms but keep positioning type when skipTransforms is true", () => {
    const node = createNode({
      type: "VECTOR",
      width: 24,
      height: 24,
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
    });
    const classes = generateTailwindClasses(node, DEFAULT_SETTINGS, true);
    // Should still contain positioning type (absolute) for layout flow
    expect(classes).toContain("absolute");
    // But should not contain x/y coordinate transforms (baked into SVG)
    expect(classes).not.toContain("left-[10px]");
    expect(classes).not.toContain("top-[20px]");
    // But should still contain size classes
    expect(classes).toContain("w-6");
    expect(classes).toContain("h-6");
  });

  it("should exclude rotation and x/y coordinates but keep positioning type when skipTransforms is true", () => {
    const node = createNode({
      type: "VECTOR",
      width: 24,
      height: 24,
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
      rotation: -45,
    });
    const classes = generateTailwindClasses(node, DEFAULT_SETTINGS, true);
    // Should not contain rotation or x/y coordinate transforms
    expect(classes).not.toMatch(/rotate-45/);
    expect(classes).not.toContain("origin-top-left");
    expect(classes).not.toContain("left-[10px]");
    expect(classes).not.toContain("top-[20px]");
    // But should still contain positioning type (absolute) for layout flow
    expect(classes).toContain("absolute");
    // And should still contain other classes like size
    expect(classes).toContain("w-6");
    expect(classes).toContain("h-6");
  });

  it("should include rotation and position when skipTransforms is false", () => {
    const node = createNode({
      type: "FRAME",
      width: 24,
      height: 24,
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
      rotation: -45,
    });
    const classes = generateTailwindClasses(node, DEFAULT_SETTINGS, false);
    // Should contain rotation and position classes
    expect(classes).toContain("absolute");
    expect(classes).toContain("left-[10px]");
    expect(classes).toContain("top-[20px]");
    expect(classes).toMatch(/rotate-45/);
  });

  it("should skip transforms by default for containers with SVG children but keep positioning type", () => {
    const svgChild = createNode({
      type: "VECTOR",
      width: 24,
      height: 24,
    });
    const container = createNode({
      type: "FRAME",
      width: 100,
      height: 100,
      layoutPositioning: "ABSOLUTE",
      x: 10,
      y: 20,
      rotation: -45,
      children: [svgChild],
    });
    // When skipTransforms is true (default for containers with SVG children)
    const classes = generateTailwindClasses(container, DEFAULT_SETTINGS, true);
    // Should not contain rotation or x/y coordinate transforms
    expect(classes).not.toMatch(/rotate-45/);
    expect(classes).not.toContain("origin-top-left");
    expect(classes).not.toContain("left-[10px]");
    expect(classes).not.toContain("top-[20px]");
    // But should still contain positioning type (absolute) for layout flow
    expect(classes).toContain("absolute");
    // And should still contain size classes (100px = w-24 in Tailwind)
    expect(classes).toContain("w-24");
    expect(classes).toContain("h-24");
  });
});


