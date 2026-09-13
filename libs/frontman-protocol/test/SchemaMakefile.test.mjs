import assert from "node:assert/strict"
import {spawnSync} from "node:child_process"
import {cp, mkdir, mkdtemp, readFile, rm, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import {join} from "node:path"
import test from "node:test"

const packageDirectory = new URL("../", import.meta.url)

test("schema recipes reject stale output and stop before deleting schemas on export failure", async t => {
  const cwd = await mkdtemp(join(tmpdir(), "frontman-schema-make-"))
  t.after(() => rm(cwd, {recursive: true, force: true}))
  await cp(new URL("Makefile", packageDirectory), join(cwd, "Makefile"))
  await mkdir(join(cwd, "scripts"))
  for (const directory of ["acp", "mcp", "jsonrpc"]) {
    await mkdir(join(cwd, "expected", directory), {recursive: true})
    await writeFile(join(cwd, "expected", directory, "schema.json"), "{}\n")
  }
  await writeFile(join(cwd, "expected/generated.json"), "{}\n")
  await cp(join(cwd, "expected"), join(cwd, "schemas"), {recursive: true})
  await mkdir(join(cwd, "schemas/acp/upstream"))
  await writeFile(join(cwd, "schemas/acp/upstream/preserved.json"), "{}\n")
  await writeFile(join(cwd, "scripts/ExportSchemas.res.mjs"), "")
  await writeFile(join(cwd, "scripts/CompactSchemas.mjs"), `
    import {cpSync} from "node:fs";
    cpSync("expected", process.argv[3], {recursive: true});
  `)
  const run = target => spawnSync("make", ["-o", "build", target], {cwd, encoding: "utf8"})
  assert.equal(run("check-schemas").status, 0)
  for (const path of ["generated.json", "acp/schema.json", "mcp/schema.json", "jsonrpc/schema.json", "mcp/stale.json", "relay/stale.json"]) {
    await mkdir(join(cwd, "schemas", path, ".."), {recursive: true})
    await writeFile(join(cwd, "schemas", path), '{"stale":true}\n')
    assert.notEqual(run("check-schemas").status, 0, path)
    const exported = run("export-schemas")
    assert.equal(exported.status, 0, exported.stderr)
    assert.equal(run("check-schemas").status, 0, path)
  }
  for (const script of ["ExportSchemas.res.mjs", "CompactSchemas.mjs"]) {
    await writeFile(join(cwd, "scripts", script), "process.exit(23)\n")
    assert.notEqual(run("check-schemas").status, 0)
    assert.notEqual(run("export-schemas").status, 0)
    assert.equal(await readFile(join(cwd, "schemas/generated.json"), "utf8"), "{}\n")
    assert.equal(await readFile(join(cwd, "schemas/mcp/schema.json"), "utf8"), "{}\n")
    await writeFile(join(cwd, "scripts", script), "")
  }
})
