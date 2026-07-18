import assert from "node:assert/strict"
import {cp, mkdtemp, readFile, rm, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import {resolve} from "node:path"
import {spawnSync} from "node:child_process"
import {fileURLToPath} from "node:url"

const [astroVersion, tarball] = process.argv.slice(2)
assert.ok(astroVersion && tarball, "Usage: node run-consumer.mjs <astro-version> <tarball>")

const root = resolve(fileURLToPath(new URL(".", import.meta.url)), "fixture")
const consumer = await mkdtemp(resolve(tmpdir(), `frontman-astro-${astroVersion.replaceAll(".", "-")}-`))

function run(command, args) {
  const result = spawnSync(command, args, {cwd: consumer, encoding: "utf8", stdio: "inherit"})
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed`)
}

try {
  await cp(root, consumer, {recursive: true})
  const packageJsonPath = resolve(consumer, "package.json")
  const packageJson = JSON.parse(await readFile(packageJsonPath, "utf8"))
  packageJson.dependencies = {
    astro: astroVersion,
    "@frontman-ai/astro": resolve(tarball),
  }
  await writeFile(packageJsonPath, JSON.stringify(packageJson, null, 2) + "\n")

  run("npm", ["install", "--strict-peer-deps", "--save-exact"])
  run("npm", ["ls", "astro", "@frontman-ai/astro", "--all"])
  run("npm", ["run", "build"])
  run(process.execPath, ["--test", "tests/package.test.mjs"])
  run(process.execPath, ["--test", "tests/dev-server.test.mjs"])
} finally {
  await rm(consumer, {recursive: true, force: true})
}
