import {parse} from "@astrojs/compiler"
import MagicString from "magic-string"

const EXCLUDED_ELEMENTS = new Set(["script", "slot", "style"])

function byteOffsetToUtf16Index(code, offset) {
  return Buffer.from(code, "utf8").subarray(0, offset).toString("utf8").length
}

function escapeAttribute(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
}

function collectElementAnnotations(node, sourceFile, edits) {
  const isLiteralElement = node.type === "element" || node.type === "custom-element"
  const hasAnnotation = node.attributes?.some(attribute => attribute.name === "data-frontman-source-file")

  if (
    isLiteralElement &&
    !EXCLUDED_ELEMENTS.has(node.name) &&
    !hasAnnotation &&
    node.position?.start
  ) {
    const start = node.position.start
    edits.push({
      offset: start.offset + Buffer.byteLength(`<${node.name}`, "utf8"),
      attributes:
        ` data-frontman-source-file="${escapeAttribute(sourceFile)}"` +
        ` data-frontman-source-loc="${start.line}:${start.column}"`,
    })
  }

  for (const child of node.children || []) {
    collectElementAnnotations(child, sourceFile, edits)
  }
}

function isPrimaryAstroRequest(id) {
  return id.endsWith(".astro") && !id.includes("?")
}

export function frontmanSourceAnnotationsPlugin() {
  return {
    name: "frontman:source-annotations",
    enforce: "pre",
    apply: "serve",
    transform: {
      order: "pre",
      async handler(code, id) {
        if (!isPrimaryAstroRequest(id)) return null

        const {ast} = await parse(code, {position: true})
        const edits = []
        collectElementAnnotations(ast, id, edits)
        if (edits.length === 0) return null

        const output = new MagicString(code)
        for (const edit of edits.reverse()) {
          output.appendLeft(byteOffsetToUtf16Index(code, edit.offset), edit.attributes)
        }

        return {
          code: output.toString(),
          map: output.generateMap({hires: true, source: id, includeContent: true}),
        }
      },
    },
  }
}
