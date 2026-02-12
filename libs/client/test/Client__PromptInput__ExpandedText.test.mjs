/**
 * Tests for getExpandedTextFromEditable and getTextFromEditable
 *
 * These are DOM-walking helpers that extract text from a contentEditable element.
 * getTextFromEditable skips chip nodes entirely.
 * getExpandedTextFromEditable inlines pasted-text chip content at their DOM position,
 * preserving the user's intended ordering.
 */
import { describe, it, expect } from "vitest";

// Import the compiled helpers from the PromptInput module
import {
  getTextFromEditable,
  getExpandedTextFromEditable,
} from "../src/components/frontman/Client__PromptInput.res.mjs";

// ============================================================================
// Test helpers
// ============================================================================

/** Create a text node */
function text(str) {
  return document.createTextNode(str);
}

/** Create a pasted-text chip element (mimics createPastedTextChipElement) */
function pasteChip(id) {
  const chip = document.createElement("span");
  chip.setAttribute("contenteditable", "false");
  chip.setAttribute("data-chip-id", id);
  chip.setAttribute("data-chip-type", "paste");
  chip.textContent = `Pasted chip ${id}`;
  return chip;
}

/** Create a file attachment chip element (mimics createFileChipElement) */
function fileChip(id) {
  const chip = document.createElement("span");
  chip.setAttribute("contenteditable", "false");
  chip.setAttribute("data-chip-id", id);
  chip.setAttribute("data-chip-type", "file");
  chip.textContent = `screenshot.png`;
  return chip;
}

/** Create a <br> element */
function br() {
  return document.createElement("br");
}

/** Create a <div> with children (contentEditable line wrapper) */
function div(...children) {
  const el = document.createElement("div");
  children.forEach((c) => el.appendChild(c));
  return el;
}

/** Build a contentEditable root from child nodes */
function editable(...children) {
  const el = document.createElement("div");
  el.setAttribute("contenteditable", "true");
  children.forEach((c) => el.appendChild(c));
  return el;
}

// ============================================================================
// Happy path
// ============================================================================

describe("getExpandedTextFromEditable", () => {
  describe("happy path", () => {
    it("returns plain text when there are no chips", () => {
      const el = editable(text("Hello world"));
      const map = new Map();
      expect(getExpandedTextFromEditable(el, map)).toBe("Hello world");
    });

    it("expands a single pasted-text chip inline", () => {
      // DOM: "Look at this: " [paste chip] " What do you think?"
      const el = editable(
        text("Look at this: "),
        pasteChip("p1"),
        text(" What do you think?")
      );
      const map = new Map([["p1", "def greet():\n  print('hi')"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "Look at this: def greet():\n  print('hi') What do you think?"
      );
    });

    it("preserves ordering with chip between two text segments", () => {
      // "Before " [chip] " After"
      const el = editable(text("Before "), pasteChip("c1"), text(" After"));
      const map = new Map([["c1", "MIDDLE CONTENT"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "Before MIDDLE CONTENT After"
      );
    });

    it("handles multiple pasted-text chips in correct order", () => {
      // "A " [chip1] " B " [chip2] " C"
      const el = editable(
        text("A "),
        pasteChip("p1"),
        text(" B "),
        pasteChip("p2"),
        text(" C")
      );
      const map = new Map([
        ["p1", "FIRST"],
        ["p2", "SECOND"],
      ]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "A FIRST B SECOND C"
      );
    });

    it("handles chip at the very start", () => {
      const el = editable(pasteChip("p1"), text(" trailing text"));
      const map = new Map([["p1", "LEADING"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "LEADING trailing text"
      );
    });

    it("handles chip at the very end", () => {
      const el = editable(text("leading text "), pasteChip("p1"));
      const map = new Map([["p1", "TRAILING"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "leading text TRAILING"
      );
    });

    it("handles only a pasted-text chip with no typed text", () => {
      const el = editable(pasteChip("p1"));
      const map = new Map([["p1", "just pasted content"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe("just pasted content");
    });

    it("handles consecutive chips with no text between them", () => {
      const el = editable(pasteChip("p1"), pasteChip("p2"));
      const map = new Map([
        ["p1", "AAA"],
        ["p2", "BBB"],
      ]);
      expect(getExpandedTextFromEditable(el, map)).toBe("AAABBB");
    });
  });

  // ============================================================================
  // File chips (should be skipped)
  // ============================================================================

  describe("file chip handling", () => {
    it("skips file attachment chips entirely", () => {
      const el = editable(
        text("text before "),
        fileChip("f1"),
        text(" text after")
      );
      const map = new Map();
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "text before  text after"
      );
    });

    it("expands paste chips but skips file chips in mixed content", () => {
      // "A " [file] " B " [paste] " C"
      const el = editable(
        text("A "),
        fileChip("f1"),
        text(" B "),
        pasteChip("p1"),
        text(" C")
      );
      const map = new Map([["p1", "PASTED"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "A  B PASTED C"
      );
    });
  });

  // ============================================================================
  // Edge cases
  // ============================================================================

  describe("edge cases", () => {
    it("returns empty string for empty editable", () => {
      const el = editable();
      const map = new Map();
      expect(getExpandedTextFromEditable(el, map)).toBe("");
    });

    it("handles BR elements as newlines", () => {
      const el = editable(text("line1"), br(), text("line2"));
      const map = new Map();
      expect(getExpandedTextFromEditable(el, map)).toBe("line1\nline2");
    });

    it("handles DIV-wrapped lines (browser contentEditable behavior)", () => {
      // Browsers often wrap lines in <div> when pressing Enter
      const el = editable(
        div(text("first line")),
        div(text("second line"))
      );
      const map = new Map();
      // First div has no preceding sibling so no newline, second div gets a newline
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "first line\nsecond line"
      );
    });

    it("handles paste chip inside a DIV wrapper", () => {
      const el = editable(
        div(text("before "), pasteChip("p1"), text(" after"))
      );
      const map = new Map([["p1", "INLINE"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "before INLINE after"
      );
    });

    it("handles chip with missing map entry (not in map) — treated as skipped", () => {
      // Paste chip whose id is not in the map — should not output anything for it
      const el = editable(text("before "), pasteChip("orphan"), text(" after"));
      const map = new Map(); // empty map
      expect(getExpandedTextFromEditable(el, map)).toBe("before  after");
    });

    it("handles multiline pasted content preserving internal newlines", () => {
      const el = editable(text("intro "), pasteChip("p1"), text(" outro"));
      const multiline = "line 1\nline 2\nline 3";
      const map = new Map([["p1", multiline]]);
      expect(getExpandedTextFromEditable(el, map)).toBe(
        "intro line 1\nline 2\nline 3 outro"
      );
    });

    it("handles whitespace-only typed text around chips", () => {
      const el = editable(text("  "), pasteChip("p1"), text("  "));
      const map = new Map([["p1", "content"]]);
      expect(getExpandedTextFromEditable(el, map)).toBe("  content  ");
    });

    it("handles deeply nested elements (P > span > text)", () => {
      const p = document.createElement("p");
      const span = document.createElement("span");
      span.appendChild(text("nested text"));
      p.appendChild(span);
      const el = editable(p);
      const map = new Map();
      expect(getExpandedTextFromEditable(el, map)).toBe("nested text");
    });
  });
});

// ============================================================================
// getTextFromEditable (original helper — should skip ALL chips)
// ============================================================================

describe("getTextFromEditable", () => {
  it("extracts plain text and skips all chip types", () => {
    const el = editable(
      text("Hello "),
      pasteChip("p1"),
      text(" World "),
      fileChip("f1"),
      text(" End")
    );
    expect(getTextFromEditable(el)).toBe("Hello  World  End");
  });

  it("returns empty string for empty editable", () => {
    const el = editable();
    expect(getTextFromEditable(el)).toBe("");
  });

  it("handles BR as newline", () => {
    const el = editable(text("a"), br(), text("b"));
    expect(getTextFromEditable(el)).toBe("a\nb");
  });

  it("handles DIV line wrapping", () => {
    const el = editable(div(text("line 1")), div(text("line 2")));
    expect(getTextFromEditable(el)).toBe("line 1\nline 2");
  });
});
