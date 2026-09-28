import {parse} from "@astrojs/compiler"
import MagicString from "magic-string"

const EXCLUDED_ELEMENTS = new Set(["script", "slot", "style"])

function byteOffsetsToUtf16Indexes(code, offsets) {
  const bytes = Buffer.from(code, "utf8")
  const indexes = new Map()
  let previousOffset = 0
  let utf16Index = 0

  for (const offset of [...new Set(offsets)].sort((left, right) => left - right)) {
    utf16Index += bytes.subarray(previousOffset, offset).toString("utf8").length
    indexes.set(offset, utf16Index)
    previousOffset = offset
  }
  return indexes
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
        const indexes = byteOffsetsToUtf16Indexes(code, edits.map(edit => edit.offset))
        for (const edit of edits.reverse()) {
          output.appendLeft(indexes.get(edit.offset), edit.attributes)
        }

        return {
          code: output.toString(),
          map: output.generateMap({hires: true, source: id, includeContent: true}),
        }
      },
    },
  }
}
