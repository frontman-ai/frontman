#!/usr/bin/env node
import {createHash} from "node:crypto"
import {copyFile, mkdir, readFile, rm, stat, writeFile} from "node:fs/promises"
import {join, resolve} from "node:path"
import {spawnSync} from "node:child_process"

const root = resolve(import.meta.dirname, "..")
const clientDist = join(root, "libs", "client", "dist")
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
const bridgeJs = join(root, "libs", "frontman-preview-bridge", "dist", "bridge.js")

await mustExist(parentJs, "Run make -C libs/client build-standalone.")
await mustExist(parentCss, "Client standalone build must emit CSS for capsules.")
await mustExist(bridgeJs, "Run make -C libs/frontman-preview-bridge build.")

const assets = [
  {name: "parent.js", source: parentJs, contentType: "text/javascript"},
  {name: "parent.css", source: parentCss, contentType: "text/css"},
  {name: "bridge.js", source: bridgeJs, contentType: "text/javascript"},
]

const hashedAssets = await Promise.all(assets.map(async (asset) => ({...asset, sha256: await sha256(asset.source)})))

const idSource = JSON.stringify(hashedAssets.map(({name, sha256}) => [name, sha256]))
const capsuleId = createHash("sha256").update(idSource).digest("hex").slice(0, 32)
const capsuleDir = join(outRoot, capsuleId)

await rm(capsuleDir, {recursive: true, force: true})
await mkdir(capsuleDir, {recursive: true})

for (const asset of hashedAssets) {
  await copyFile(asset.source, join(capsuleDir, asset.name))
}

const immutableCacheControl = "public, max-age=31536000, immutable"
const manifest = {
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

const capsuleRef = {capsuleId, manifestPath: `/capsules/${capsuleId}/manifest.json`}
await writeFile(join(capsuleDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`)
await mkdir(join(root, "dist"), {recursive: true})
await writeFile(join(root, "dist", "frontman-capsule.json"), `${JSON.stringify(capsuleRef, null, 2)}\n`)
await writeFile(join(clientDist, "frontman-capsule.json"), `${JSON.stringify(capsuleRef, null, 2)}\n`)

console.log(capsuleId)
