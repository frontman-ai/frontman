import { describe, it, expect } from "vitest";
import {
  hasTextDescendant,
  isLikelyIcon,
  isVectorOnlyContainer,
  hasImageFill,
  retrieveTopFill,
  needsAbsolutePositioning,
  needsRelativePositioning,
  hasSvgChildren,
  ICON_TYPES,
  CONTAINER_TYPES,
} from "../src/detection.js";
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
    width: 100,
    height: 100,
    ...overrides,
  };
}

describe("hasTextDescendant", () => {
  it("should return true for TEXT nodes", () => {
    const node = createNode({ type: "TEXT" });
    expect(hasTextDescendant(node)).toBe(true);
  });

  it("should return false for non-TEXT nodes without children", () => {
    const node = createNode({ type: "FRAME" });
    expect(hasTextDescendant(node)).toBe(false);
  });

  it("should detect TEXT in nested children", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({
          type: "GROUP",
          children: [createNode({ type: "TEXT" })],
        }),
      ],
    });
    expect(hasTextDescendant(node)).toBe(true);
  });

  it("should ignore invisible children", () => {
    const node = createNode({
      type: "FRAME",
      children: [createNode({ type: "TEXT", visible: false })],
    });
    expect(hasTextDescendant(node)).toBe(false);
  });
});

describe("isLikelyIcon", () => {
  it("should return true for VECTOR types", () => {
    const node = createNode({ type: "VECTOR", width: 24, height: 24 });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(true);
  });

  it("should return true for ELLIPSE", () => {
    const node = createNode({ type: "ELLIPSE", width: 24, height: 24 });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(true);
  });

  it("should return false for TEXT nodes", () => {
    const node = createNode({ type: "TEXT" });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should return false for invisible nodes", () => {
    const node = createNode({ type: "VECTOR", visible: false });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should return true for small containers with only vectors", () => {
    const node = createNode({
      type: "FRAME",
      width: 32,
      height: 32,
      children: [
        createNode({ type: "VECTOR", width: 24, height: 24 }),
        createNode({ type: "ELLIPSE", width: 8, height: 8 }),
      ],
    });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(true);
  });

  it("should return false for containers with text", () => {
    const node = createNode({
      type: "FRAME",
      width: 32,
      height: 32,
      children: [
        createNode({ type: "VECTOR" }),
        createNode({ type: "TEXT" }),
      ],
    });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should return false for large containers", () => {
    const node = createNode({
      type: "FRAME",
      width: 200,
      height: 200,
      children: [createNode({ type: "VECTOR" })],
    });
    expect(isLikelyIcon(node, DEFAULT_SETTINGS)).toBe(false);
  });
});

describe("isVectorOnlyContainer", () => {
  it("should return true for container with only vectors", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({ type: "VECTOR" }),
        createNode({ type: "ELLIPSE" }),
        createNode({ type: "RECTANGLE" }),
      ],
    });
    expect(isVectorOnlyContainer(node)).toBe(true);
  });

  it("should return false for containers with text", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({ type: "VECTOR" }),
        createNode({ type: "TEXT" }),
      ],
    });
    expect(isVectorOnlyContainer(node)).toBe(false);
  });

  it("should return false for non-container types", () => {
    const node = createNode({ type: "VECTOR" });
    expect(isVectorOnlyContainer(node)).toBe(false);
  });

  it("should handle nested vector containers", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({
          type: "GROUP",
          children: [createNode({ type: "VECTOR" })],
        }),
      ],
    });
    expect(isVectorOnlyContainer(node)).toBe(true);
  });
});

describe("hasImageFill", () => {
  it("should return true when fills contain IMAGE", () => {
    const fills: Paint[] = [{ type: "IMAGE" }];
    expect(hasImageFill(fills)).toBe(true);
  });

  it("should return false when no IMAGE fill", () => {
    const fills: Paint[] = [{ type: "SOLID" }];
    expect(hasImageFill(fills)).toBe(false);
  });

  it("should return false for undefined fills", () => {
    expect(hasImageFill(undefined)).toBe(false);
  });
});

describe("retrieveTopFill", () => {
  it("should return the last visible fill", () => {
    const fills: Paint[] = [
      { type: "SOLID", color: { r: 1, g: 0, b: 0 } },
      { type: "SOLID", color: { r: 0, g: 1, b: 0 } },
    ];
    const top = retrieveTopFill(fills);
    expect(top?.color).toEqual({ r: 0, g: 1, b: 0 });
  });

  it("should skip invisible fills", () => {
    const fills: Paint[] = [
      { type: "SOLID", visible: true, color: { r: 1, g: 0, b: 0 } },
      { type: "SOLID", visible: false, color: { r: 0, g: 1, b: 0 } },
    ];
    const top = retrieveTopFill(fills);
    expect(top?.color).toEqual({ r: 1, g: 0, b: 0 });
  });

  it("should return undefined for empty array", () => {
    expect(retrieveTopFill([])).toBeUndefined();
  });
});

describe("needsAbsolutePositioning", () => {
  it("should return true for ABSOLUTE positioning", () => {
    const node = createNode({
      type: "FRAME",
      layoutPositioning: "ABSOLUTE",
    });
    expect(needsAbsolutePositioning(node)).toBe(true);
  });

  it("should return true when parent has no layout", () => {
    const parent = createNode({ type: "FRAME" });
    const node = createNode({
      type: "RECTANGLE",
      x: 10,
      y: 20,
      parent,
    });
    expect(needsAbsolutePositioning(node)).toBe(true);
  });

  it("should return false for AUTO positioning with layout parent", () => {
    const parent = createNode({
      type: "FRAME",
      layoutMode: "HORIZONTAL",
    });
    const node = createNode({
      type: "RECTANGLE",
      layoutPositioning: "AUTO",
      parent,
    });
    expect(needsAbsolutePositioning(node)).toBe(false);
  });
});

describe("needsRelativePositioning", () => {
  it("should return true when has absolutely positioned children", () => {
    const child = createNode({
      type: "RECTANGLE",
      layoutPositioning: "ABSOLUTE",
    });
    const node = createNode({
      type: "FRAME",
      children: [child],
    });
    expect(needsRelativePositioning(node)).toBe(true);
  });

  it("should return false when no children", () => {
    const node = createNode({ type: "FRAME" });
    expect(needsRelativePositioning(node)).toBe(false);
  });
});

describe("hasSvgChildren", () => {
  it("should return true for container with VECTOR children", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({ type: "VECTOR", width: 24, height: 24 }),
        createNode({ type: "ELLIPSE", width: 24, height: 24 }),
      ],
    });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(true);
  });

  it("should return true for container with vector-only container child", () => {
    const vectorContainer = createNode({
      type: "GROUP",
      children: [createNode({ type: "VECTOR", width: 24, height: 24 })],
    });
    const node = createNode({
      type: "FRAME",
      children: [vectorContainer],
    });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(true);
  });

  it("should return false for container with only TEXT children", () => {
    const node = createNode({
      type: "FRAME",
      children: [createNode({ type: "TEXT" })],
    });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should return false for container with no children", () => {
    const node = createNode({ type: "FRAME" });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should ignore invisible children", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({ type: "VECTOR", width: 24, height: 24, visible: false }),
      ],
    });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(false);
  });

  it("should return true for container with likely icon child", () => {
    const node = createNode({
      type: "FRAME",
      children: [
        createNode({
          type: "FRAME",
          width: 32,
          height: 32,
          children: [createNode({ type: "VECTOR", width: 24, height: 24 })],
        }),
      ],
    });
    expect(hasSvgChildren(node, DEFAULT_SETTINGS)).toBe(true);
  });
});

describe("type sets", () => {
  it("ICON_TYPES should include vector shapes", () => {
    expect(ICON_TYPES.has("VECTOR")).toBe(true);
    expect(ICON_TYPES.has("ELLIPSE")).toBe(true);
    expect(ICON_TYPES.has("RECTANGLE")).toBe(true);
    expect(ICON_TYPES.has("POLYGON")).toBe(true);
  });

  it("CONTAINER_TYPES should include frames and groups", () => {
    expect(CONTAINER_TYPES.has("FRAME")).toBe(true);
    expect(CONTAINER_TYPES.has("GROUP")).toBe(true);
    expect(CONTAINER_TYPES.has("COMPONENT")).toBe(true);
    expect(CONTAINER_TYPES.has("INSTANCE")).toBe(true);
  });
});


