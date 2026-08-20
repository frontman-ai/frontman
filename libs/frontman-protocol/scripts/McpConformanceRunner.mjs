import {spawn, spawnSync} from "node:child_process"
import {createHash} from "node:crypto"
import {existsSync, mkdtempSync, readFileSync, readdirSync, rmSync} from "node:fs"
import {join, resolve} from "node:path"

export const runnerVersion = "0.2.0-alpha.11"
export const runnerChecksum = "67d28b0d50d64458232945d9b3af75178add5d05819c748ec2c8b26e5cb038c5"
export const serverScenarios = [
  "tools-list",
  "tools-call-simple-text",
  "tools-call-image",
  "tools-call-audio",
  "tools-call-embedded-resource",
  "tools-call-mixed-content",
  "tools-call-error",
]
export const clientScenarios = [
  "tools_call",
  "request-metadata",
  "http-standard-headers",
  "http-custom-headers",
  "http-invalid-tool-headers",
  "json-schema-ref-no-deref",
]

const permittedCapabilitySkips = {
  "request-metadata": new Set([
    "ClientDeclaresRootsCapability",
    "ClientDeclaresSamplingCapability",
    "ClientDeclaresElicitationCapability",
  ]),
  "http-standard-headers": new Set([
    "ClientMcpMethodHeader_initialize",
    "ClientMcpMethodHeader_notifications_initialized",
    "ClientMcpMethodHeader_resources_list",
    "ClientMcpMethodHeader_resources_read",
    "ClientMcpMethodHeader_prompts_list",
    "ClientMcpMethodHeader_prompts_get",
    "ClientMcpNameHeader_resources_read",
    "ClientMcpNameHeader_prompts_get",
  ]),
}

const root = resolve(import.meta.dirname, "../../..")
const archive = resolve(
  import.meta.dirname,
  "../test/mcp-upstream/conformance/modelcontextprotocol-conformance-0.2.0-alpha.11.tgz",
)
const guard = resolve(root, "test/mcp-conformance/network-guard.mjs")
const clientHarness = resolve(root, "test/mcp-conformance/client.mjs")
const archiveEntries = [
  "package/LICENSE",
  "package/README.md",
  "package/dist/index.js",
  "package/package.json",
  "package/requirements/2025-11-25.yaml",
  "package/requirements/2026-07-28.yaml",
]

const checksum = file => createHash("sha256").update(readFileSync(file)).digest("hex")

const shellQuote = value => `'${value.replaceAll("'", `'\\''`)}'`

export const runnerPermissionArgs = directory => [
  "--max-old-space-size=512",
  "--permission",
  `--allow-fs-read=${directory}`,
  `--allow-fs-read=${resolve(root, "node_modules")}`,
  `--allow-fs-read=${resolve(root, "package.json")}`,
  `--allow-fs-read=${resolve(root, "libs/bindings")}`,
  `--allow-fs-read=${resolve(root, "libs/frontman-client")}`,
  `--allow-fs-read=${resolve(root, "libs/frontman-protocol")}`,
  `--allow-fs-read=${resolve(root, "libs/logs")}`,
  `--allow-fs-read=${guard}`,
  `--allow-fs-read=${clientHarness}`,
  `--allow-fs-write=${directory}`,
  "--allow-worker",
]

const checksFiles = directory => {
  const found = []
  for (const entry of readdirSync(directory, {withFileTypes: true})) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) found.push(...checksFiles(path))
    if (entry.isFile() && entry.name === "checks.json") found.push(path)
  }
  return found
}

export function verifyRunnerArchive() {
  if (checksum(archive) !== runnerChecksum) throw new Error("Pinned MCP conformance runner checksum mismatch")
  const listing = spawnSync("tar", ["-tzf", archive], {encoding: "utf8"})
  if (listing.status !== 0) throw new Error(`Unable to inspect MCP conformance runner: ${listing.stderr}`)
  const entries = listing.stdout.trim().split("\n").sort()
  if (JSON.stringify(entries) !== JSON.stringify([...archiveEntries].sort())) {
    throw new Error("Pinned MCP conformance runner contains an unexpected archive entry")
  }
  const verboseListing = spawnSync("tar", ["-tvzf", archive], {encoding: "utf8"})
  if (verboseListing.status !== 0) {
    throw new Error(`Unable to inspect MCP conformance runner entry types: ${verboseListing.stderr}`)
  }
  const entryTypes = verboseListing.stdout.trim().split("\n").map(entry => entry[0])
  if (entryTypes.length !== archiveEntries.length || entryTypes.some(type => type !== "-")) {
    throw new Error("Pinned MCP conformance runner contains a non-regular archive entry")
  }
}

export function extractRunner(directory) {
  verifyRunnerArchive()
  const extraction = spawnSync("tar", ["-xzf", archive, "-C", directory], {encoding: "utf8"})
  if (extraction.status !== 0) throw new Error(`Unable to extract MCP conformance runner: ${extraction.stderr}`)
  const manifest = JSON.parse(readFileSync(join(directory, "package/package.json"), "utf8"))
  if (manifest.name !== "@modelcontextprotocol/conformance" || manifest.version !== runnerVersion) {
    throw new Error("Pinned MCP conformance runner identity mismatch")
  }
  return join(directory, "package/dist/index.js")
}

const executeRunner = (args, options) => new Promise(resolveExecution => {
  const child = spawn(process.execPath, args, options)
  const outputLimit = 1024 * 1024
  let stdout = ""
  let stderr = ""
  let error
  const capture = (current, chunk) => {
    if (current.length + chunk.length <= outputLimit) return current + chunk
    error ??= new Error("Official MCP conformance runner exceeded the output limit")
    child.kill("SIGKILL")
    return current
  }
  child.stdout.on("data", chunk => stdout = capture(stdout, chunk))
  child.stderr.on("data", chunk => stderr = capture(stderr, chunk))
  child.on("error", value => error = value)
  const timer = setTimeout(() => child.kill("SIGKILL"), 60000)
  child.on("close", status => {
    clearTimeout(timer)
    resolveExecution({status, stdout, stderr, error})
  })
})

export async function runScenario({mode, scenario, serverUrl}) {
  const directory = mkdtempSync(join(root, ".mcp-conformance-"))
  try {
    const runner = extractRunner(directory)
    const output = join(directory, "results")
    const clientExecutable = shellQuote(process.execPath)
    const quotedClientHarness = shellQuote(clientHarness)
    const args = [
      ...runnerPermissionArgs(directory),
      runner,
      mode,
    ]
    if (mode === "server") args.push("--url", serverUrl)
    if (mode === "client") {
      const command = `${clientExecutable} ${quotedClientHarness}`
      args.push("--command", command)
    }
    args.push("--scenario", scenario, "--spec-version", "2026-07-28", "--output-dir", output)
    const execution = await executeRunner(args, {
      cwd: directory,
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        HOME: directory,
        NODE_OPTIONS: `--import=${guard}`,
        TMPDIR: directory,
        FRONTMAN_ROOT: root,
        FRONTMAN_CONFORMANCE_CLIENT_EXECUTABLE: clientExecutable,
        FRONTMAN_CONFORMANCE_CLIENT_HARNESS: quotedClientHarness,
        FRONTMAN_CONFORMANCE_CLIENT_HARNESS_PATH: clientHarness,
      },
    })
    if (!existsSync(output)) {
      throw new Error(
        `Official MCP conformance scenario ${scenario} produced no output\n${execution.stderr}\n${execution.stdout}`,
      )
    }
    const files = checksFiles(output)
    if (files.length !== 1) {
      throw new Error(
        `Official MCP conformance scenario ${scenario} produced ${files.length} check files\n${execution.stderr}\n${execution.stdout}`,
      )
    }
    const checks = JSON.parse(readFileSync(files[0], "utf8"))
    const failures = checks.filter(check => check.status === "FAILURE")
    const warnings = checks.filter(check => check.status === "WARNING")
    const permittedSkips = permittedCapabilitySkips[scenario] ?? new Set()
    const unexpectedSkips = checks.filter(
      check => check.status === "SKIPPED" && !permittedSkips.has(check.name),
    )
    if (
      execution.error ||
      execution.status !== 0 ||
      failures.length > 0 ||
      warnings.length > 0 ||
      unexpectedSkips.length > 0
    ) {
      const rejectedChecks = [...failures, ...warnings, ...unexpectedSkips]
      const details = rejectedChecks
        .map(check => `${check.id}: ${check.errorMessage ?? check.status}`)
        .join("\n")
      throw new Error(
        `Official MCP conformance scenario ${scenario} failed\n${details}\n${execution.stderr}\n${execution.stdout}`,
      )
    }
    return checks
  } finally {
    rmSync(directory, {recursive: true, force: true})
  }
}
