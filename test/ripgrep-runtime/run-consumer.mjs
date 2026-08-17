import assert from "node:assert/strict"
import {mkdtemp, rm, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import {resolve} from "node:path"
import {spawnSync} from "node:child_process"
import {pathToFileURL} from "node:url"

const [integration, tarball] = process.argv.slice(2)
assert.ok(integration && tarball, "Usage: node run-consumer.mjs <nextjs|vite> <tarball>")

const packageConfig = {
  nextjs: {
    packageName: "@frontman-ai/nextjs",
    peers: {next: "13.2.0", react: "18.2.0", "react-dom": "18.2.0"},
  },
  vite: {packageName: "@frontman-ai/vite", peers: {vite: "5.0.0"}},
}[integration]
assert.ok(packageConfig, `Unsupported integration: ${integration}`)

const consumer = await mkdtemp(resolve(tmpdir(), `frontman-${integration}-ripgrep-`))

function run(command, args) {
  const result = spawnSync(command, args, {cwd: consumer, stdio: "inherit"})
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed`)
}

try {
  const packageJson = {
    name: "frontman-ripgrep-consumer",
    private: true,
    type: "module",
    dependencies: {...packageConfig.peers, [packageConfig.packageName]: resolve(tarball)},
  }
  await writeFile(resolve(consumer, "package.json"), JSON.stringify(packageJson, null, 2) + "\n")
  await writeFile(resolve(consumer, "search-target.txt"), "packed ripgrep runtime\n")
  run("npm", ["install", "--strict-peer-deps", "--save-exact"])

  const packageRoot = resolve(consumer, "node_modules", packageConfig.packageName)
  const frontman = await import(pathToFileURL(resolve(packageRoot, "dist", "index.js")))
  const configInput = {projectRoot: consumer, sourceRoot: consumer, basePath: "frontman"}
  const middleware = integration === "nextjs"
    ? frontman.createMiddleware(configInput)
    : frontman.createMiddleware(frontman.makeConfig(configInput))
  const request = new Request("http://localhost/frontman/tools/call", {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({name: "search_files", arguments: {pattern: "search-target.txt"}}),
  })
  const response = await middleware(request)
  assert.equal(response?.status, 200)
  assert.match(await response.text(), /search-target\.txt/)
} finally {
  await rm(consumer, {recursive: true, force: true})
}
