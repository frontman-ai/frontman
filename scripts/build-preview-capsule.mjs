#!/usr/bin/env node
import {createHash} from "node:crypto"
import {copyFile, mkdir, readFile, rename, rm, stat, writeFile} from "node:fs/promises"
import {join, resolve} from "node:path"
import {spawnSync} from "node:child_process"

const root = resolve(import.meta.dirname, "..")
const clientDist = process.env.FRONTMAN_CAPSULE_CLIENT_DIST ?? join(root, "libs", "client", "dist")
const bridgeDist = process.env.FRONTMAN_CAPSULE_BRIDGE_DIST ?? join(root, "libs", "frontman-preview-bridge", "dist")
const refDist = process.env.FRONTMAN_CAPSULE_REF_DIST ?? join(root, "dist")
const outRoot = join(clientDist, "capsules")

function run(command, args, cwd = root) {
  const result = spawnSync(command, args, {cwd, stdio: "inherit", shell: process.platform === "win32"})
  if (result.status !== 0) process.exit(result.status ?? 1)
}

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex")
}

async function mustExist(path, hint) {
  await stat(path).catch(() => {
    throw new Error(`${path} missing. ${hint}`)
  })
}

run("make", ["-C", "libs/client", "build-standalone"])
run("make", ["-C", "libs/frontman-preview-bridge", "build"])

const parentJs = join(clientDist, "frontman.es.js")
const parentCss = join(clientDist, "frontman.css")
const bridgeJs = join(bridgeDist, "bridge.js")

await mustExist(parentJs, "Run make -C libs/client build-standalone.")
await mustExist(parentCss, "Client standalone build must emit CSS for capsules.")
await mustExist(bridgeJs, "Run make -C libs/frontman-preview-bridge build.")

const assets = [
  {name: "parent.js", source: parentJs, contentType: "text/javascript"},
  {name: "parent.css", source: parentCss, contentType: "text/css"},
  {name: "bridge.js", source: bridgeJs, contentType: "text/javascript"},
]

const hashedAssets = await Promise.all(assets.map(async (asset) => ({...asset, sha256: await sha256(asset.source)})))
const immutableCacheControl = "public, max-age=31536000, immutable"
const manifestVersion = 1
const idSource = JSON.stringify({
  version: manifestVersion,
  cacheControl: immutableCacheControl,
  assets: hashedAssets.map(({name, sha256, contentType}) => ({
    name,
    sha256,
    contentType,
    cacheControl: immutableCacheControl,
  })),
})
const capsuleId = createHash("sha256").update(idSource).digest("hex").slice(0, 32)
const capsuleDir = join(outRoot, capsuleId)
const stageDir = join(outRoot, `.${capsuleId}-${process.pid}.tmp`)
const manifest = {
  version: manifestVersion,
  capsuleId,
  cacheControl: immutableCacheControl,
  assets: Object.fromEntries(hashedAssets.map((asset) => [
    asset.name,
    {
      path: `/capsules/${capsuleId}/${asset.name}`,
      sha256: asset.sha256,
      contentType: asset.contentType,
      cacheControl: immutableCacheControl,
    },
  ])),
}

async function capsuleMatches() {
  try {
    assertJsonEqual(JSON.parse(await readFile(join(capsuleDir, "manifest.json"), "utf8")), manifest)
    await Promise.all(hashedAssets.map(async (asset) => {
      if (await sha256(join(capsuleDir, asset.name)) !== asset.sha256) throw new Error("asset mismatch")
    }))
    return true
  } catch {
    return false
  }
}

function assertJsonEqual(left, right) {
  if (JSON.stringify(left) !== JSON.stringify(right)) throw new Error("manifest mismatch")
}

if (!await capsuleMatches()) {
  await rm(stageDir, {recursive: true, force: true})
  await mkdir(stageDir, {recursive: true})

  for (const asset of hashedAssets) {
    await copyFile(asset.source, join(stageDir, asset.name))
  }

  await writeFile(join(stageDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`)
  await rm(capsuleDir, {recursive: true, force: true})
  await rename(stageDir, capsuleDir)
}

const capsuleRef = {capsuleId, manifestPath: `/capsules/${capsuleId}/manifest.json`}
await mkdir(refDist, {recursive: true})
await writeFile(join(refDist, "frontman-capsule.json"), `${JSON.stringify(capsuleRef, null, 2)}\n`)
await writeFile(join(clientDist, "frontman-capsule.json"), `${JSON.stringify(capsuleRef, null, 2)}\n`)

console.log(capsuleId)
