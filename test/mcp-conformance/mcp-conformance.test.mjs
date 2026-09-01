import assert from "node:assert/strict"
import {spawnSync} from "node:child_process"
import {createServer} from "node:http"
import {resolve} from "node:path"
import test from "node:test"
import {
  clientScenarios,
  runScenario,
  runnerPermissionArgs,
  runnerChecksum,
  runnerVersion,
  serverScenarios,
  verifyRunnerArchive,
} from "../../libs/frontman-protocol/scripts/McpConformanceRunner.mjs"

globalThis.__PACKAGE_VERSION__ = "1.0.0"
const {makeMiddleware} = await import(
  "../../libs/frontman-vite/test/FrontmanVite__ConformanceServer.res.mjs"
)

const listen = server => new Promise((resolve, reject) => {
  server.once("error", reject)
  server.listen(0, "127.0.0.1", () => resolve())
})

const close = server => new Promise((resolve, reject) => {
  server.close(error => error ? reject(error) : resolve())
})

test("official MCP conformance runner identity and archive are pinned", () => {
  assert.equal(runnerVersion, "0.2.0-alpha.11")
  assert.equal(runnerChecksum, "67d28b0d50d64458232945d9b3af75178add5d05819c748ec2c8b26e5cb038c5")
  assert.doesNotThrow(verifyRunnerArchive)
})

test("official MCP conformance execution blocks non-loopback sockets", () => {
  const guard = resolve(import.meta.dirname, "network-guard.mjs")
  const probe = spawnSync(
    process.execPath,
    ["-e", "fetch('https://example.com').then(() => process.exit(1), () => process.exit(0))"],
    {env: {NODE_OPTIONS: `--import=${guard}`}},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution blocks alternate network transports", () => {
  const guard = resolve(import.meta.dirname, "network-guard.mjs")
  const probe = spawnSync(
    process.execPath,
    [
      "-e",
      `const net = require("node:net"); const dgram = require("node:dgram"); const dns = require("node:dns");
       for (const attempt of [
         () => net.connect("/var/run/docker.sock"),
         () => dgram.createSocket("udp4"),
         () => new dgram.Socket("udp4"),
         () => dns.resolve4("example.com"),
         () => new dns.Resolver(),
         () => new dns.promises.Resolver(),
       ]) {
         try { attempt(); process.exit(1) } catch {}
       }`,
    ],
    {env: {NODE_OPTIONS: `--import=${guard}`}},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution cannot override localhost resolution", () => {
  const guard = resolve(import.meta.dirname, "network-guard.mjs")
  const probe = spawnSync(
    process.execPath,
    [
      "-e",
      `const net = require("node:net"); let lookupCalled = false;
       const socket = net.connect({host: "localhost", port: 1, lookup: () => lookupCalled = true});
       socket.on("error", () => {});
       setTimeout(() => process.exit(lookupCalled ? 1 : 0), 25);`,
    ],
    {env: {NODE_OPTIONS: `--import=${guard}`}},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution blocks unapproved child processes", () => {
  const guard = resolve(import.meta.dirname, "network-guard.mjs")
  const probe = spawnSync(
    process.execPath,
    ["-e", "try { require('node:child_process').spawnSync('curl', ['https://example.com']); process.exit(1) } catch { process.exit(0) }"],
    {env: {NODE_OPTIONS: `--import=${guard}`}},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution blocks unapproved workers", () => {
  const guard = resolve(import.meta.dirname, "network-guard.mjs")
  const probe = spawnSync(
    process.execPath,
    ["-e", "try { new (require('node:worker_threads').Worker)('0', {eval: true}); process.exit(1) } catch { process.exit(0) }"],
    {env: {NODE_OPTIONS: `--import=${guard}`}},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution cannot write to the repository", () => {
  const probe = spawnSync(
    process.execPath,
    [
      "--permission",
      `--allow-fs-read=${resolve(import.meta.dirname, "../..")}`,
      `--allow-fs-write=${resolve(import.meta.dirname)}`,
      "-e",
      "try { require('node:fs').writeFileSync('forbidden-conformance-write', 'x'); process.exit(1) } catch { process.exit(0) }",
    ],
    {cwd: resolve(import.meta.dirname, "../..")},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP conformance execution cannot read repository metadata", () => {
  const root = resolve(import.meta.dirname, "../..")
  const args = runnerPermissionArgs(import.meta.dirname)
  assert.ok(!args.includes("--allow-child-process"))
  const probe = spawnSync(
    process.execPath,
    [
      ...args,
      "-e",
      "try { require('node:fs').readFileSync('.git/config'); process.exit(1) } catch { process.exit(0) }",
    ],
    {cwd: root},
  )
  assert.equal(probe.status, 0, probe.stderr?.toString())
})

test("official MCP server scenarios pass against the Frontman endpoint", {timeout: 120000}, async () => {
  let middleware
  let origin
  const server = createServer((request, response) => {
    if (!request.headers.origin) {
      request.headers.origin = origin
      request.rawHeaders.push("Origin", origin)
    }
    void middleware(request, response, () => {
      response.statusCode = 404
      response.end()
    })
  })
  await listen(server)
  const address = server.address()
  origin = `http://127.0.0.1:${address.port}`
  middleware = makeMiddleware([origin])
  try {
    for (const scenario of serverScenarios) {
      const checks = await runScenario({mode: "server", scenario, serverUrl: `${origin}/mcp`})
      assert.ok(checks.length > 0, `${scenario} produced no checks`)
    }
  } finally {
    await close(server)
  }
})

test("official MCP client scenarios pass against the Frontman client", {timeout: 120000}, async () => {
  for (const scenario of clientScenarios) {
    const checks = await runScenario({mode: "client", scenario})
    assert.ok(checks.length > 0, `${scenario} produced no checks`)
  }
})
