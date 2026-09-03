import assert from "node:assert/strict"
import {createHash} from "node:crypto"
import {chmod, mkdir, mkdtemp, readdir, readFile, rm, writeFile} from "node:fs/promises"
import {existsSync} from "node:fs"
import {join, resolve} from "node:path"
import {test} from "node:test"
import {spawnSync} from "node:child_process"
import {tmpdir} from "node:os"

const root = resolve(import.meta.dirname, "..")
const script = join(root, "scripts", "build-preview-capsule.mjs")

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex")
}

test("build-preview-capsule emits one immutable parent/bridge capsule", async (t) => {
  const fakeBin = await mkdtemp(join(tmpdir(), "frontman-capsule-bin-"))
  t.after(() => rm(fakeBin, {recursive: true, force: true}))
  const fakeMake = join(fakeBin, "make")
  await Promise.all([
    mkdir(join(root, "libs", "client", "dist"), {recursive: true}),
    mkdir(join(root, "libs", "frontman-preview-bridge", "dist"), {recursive: true}),
  ])
  await writeFile(fakeMake, "#!/bin/sh\nexit 0\n")
  await chmod(fakeMake, 0o755)

  await Promise.all([
    writeFile(join(root, "libs", "client", "dist", "frontman.es.js"), "console.log('parent')\n"),
    writeFile(join(root, "libs", "client", "dist", "frontman.css"), ".frontman{}\n"),
    writeFile(join(root, "libs", "frontman-preview-bridge", "dist", "bridge.js"), "console.log('bridge')\n"),
  ])

  const result = spawnSync(process.execPath, [script], {
    cwd: root,
    env: {...process.env, PATH: `${fakeBin}:${process.env.PATH}`},
    encoding: "utf8",
  })

  assert.equal(result.status, 0, result.stderr)
  const capsuleId = result.stdout.trim()
  assert.match(capsuleId, /^[a-f0-9]{32}$/)

  const dir = join(root, "libs", "client", "dist", "capsules", capsuleId)
  assert.deepEqual(await readdir(dir), ["bridge.js", "manifest.json", "parent.css", "parent.js"])

  const manifest = JSON.parse(await readFile(join(dir, "manifest.json"), "utf8"))
  assert.equal(manifest.capsuleId, capsuleId)
  assert.equal(manifest.cacheControl, "public, max-age=31536000, immutable")
  assert.equal(manifest.assets["parent.js"].sha256, await sha256(join(dir, "parent.js")))
  assert.equal(manifest.assets["parent.css"].contentType, "text/css")
  assert.equal(manifest.assets["bridge.js"].contentType, "text/javascript")
  assert.equal(manifest.assets["bridge.js"].path, `/capsules/${capsuleId}/bridge.js`)

  const ref = {capsuleId, manifestPath: `/capsules/${capsuleId}/manifest.json`}
  assert.deepEqual(JSON.parse(await readFile(join(root, "dist", "frontman-capsule.json"), "utf8")), ref)
  assert.deepEqual(JSON.parse(await readFile(join(root, "libs", "client", "dist", "frontman-capsule.json"), "utf8")), ref)

  assert.equal(existsSync(join(dir, "latest")), false)
})
