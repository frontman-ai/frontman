import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import {basename} from "node:path"

const [manifestPath] = process.argv.slice(2)
assert.ok(manifestPath, "Usage: node assert-pack.mjs <npm-pack-json>")

const [packed] = JSON.parse(await readFile(manifestPath, "utf8"))
const files = new Set(packed.files.map(file => file.path))

assert.equal(basename(packed.filename), `frontman-ai-astro-${packed.version}.tgz`)
for (const path of ["package.json", "README.md", "index.d.ts", "dist/index.js", "dist/integration.js", "dist/toolbar.js"]) {
  assert.ok(files.has(path), `Packed artifact missing ${path}`)
}
