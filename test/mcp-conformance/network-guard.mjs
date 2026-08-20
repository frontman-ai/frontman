import childProcess from "node:child_process"
import dgram from "node:dgram"
import dns from "node:dns"
import {EventEmitter} from "node:events"
import {syncBuiltinESMExports} from "node:module"
import net from "node:net"
import {pathToFileURL} from "node:url"
import workerThreads from "node:worker_threads"

const OriginalWorker = workerThreads.Worker

const originalConnect = net.Socket.prototype.connect
const originalCreateConnection = net.createConnection
const permitted = new Set(["localhost", "127.0.0.1", "::1"])

const createConnection = function(...args) {
  if (typeof args[0] === "string") {
    throw new Error(`MCP conformance Unix socket access denied: ${args[0]}`)
  }
  return originalCreateConnection.apply(this, args)
}
net.connect = createConnection
net.createConnection = createConnection

net.Socket.prototype.connect = function(...args) {
  const connectArgs = Array.isArray(args[0]) ? args[0] : args
  const first = connectArgs[0]
  if (typeof first === "string") {
    throw new Error(`MCP conformance Unix socket access denied: ${first}`)
  }
  const host = typeof first === "object" && first !== null
    ? first.host ?? first.hostname ?? "localhost"
    : typeof connectArgs[1] === "string"
      ? connectArgs[1]
      : "localhost"
  if (typeof first === "object" && first !== null && first.path) {
    throw new Error(`MCP conformance Unix socket access denied: ${first.path}`)
  }
  if (!permitted.has(host)) throw new Error(`MCP conformance network access denied: ${host}`)
  if (typeof first === "object" && first !== null) {
    const safeOptions = {host: host === "localhost" ? "127.0.0.1" : host, port: first.port}
    return originalConnect.apply(this, [safeOptions, ...connectArgs.slice(1)])
  }
  return originalConnect.apply(this, connectArgs)
}

const deniedNetwork = () => {
  throw new Error("MCP conformance non-loopback network access denied")
}
dns.lookup = function(hostname, ...args) {
  if (!permitted.has(hostname)) return deniedNetwork()
  const options = typeof args[0] === "object" ? args[0] : {}
  const callback = args.find(value => typeof value === "function")
  const result = options.all ? [{address: "127.0.0.1", family: 4}] : "127.0.0.1"
  queueMicrotask(() => options.all ? callback(null, result) : callback(null, result, 4))
}
for (const method of ["lookupService", "resolve", "resolve4", "resolve6", "resolveAny", "resolveCaa", "resolveCname", "resolveMx", "resolveNaptr", "resolveNs", "resolvePtr", "resolveSoa", "resolveSrv", "resolveTxt", "reverse"]) {
  dns[method] = deniedNetwork
  dns.promises[method] = deniedNetwork
}
dns.promises.lookup = function(hostname, ...args) {
  if (!permitted.has(hostname)) return Promise.reject(new Error("MCP conformance DNS access denied"))
  const options = typeof args[0] === "object" ? args[0] : {}
  return Promise.resolve(
    options.all ? [{address: "127.0.0.1", family: 4}] : {address: "127.0.0.1", family: 4},
  )
}
dgram.createSocket = deniedNetwork
dns.Resolver = class ConformanceResolver {
  constructor() {
    return deniedNetwork()
  }
}
dns.promises.Resolver = class ConformancePromiseResolver {
  constructor() {
    return deniedNetwork()
  }
}
dgram.Socket = class ConformanceDatagramSocket {
  constructor() {
    return deniedNetwork()
  }
}

const deniedChildProcess = () => {
  throw new Error("MCP conformance child process denied")
}
let clientWorkerStarted = false
let schemaWorkerCount = 0
const schemaWorkerSource = `
      import {parentPort, workerData} from 'node:worker_threads'
      globalThis.self = {
        onmessage: undefined,
        postMessage: value => parentPort.postMessage(value),
      }
      parentPort.on('message', data => globalThis.self.onmessage({data}))
      await import(workerData.url)
    `
const schemaWorkerUrl = pathToFileURL(
  `${process.env.FRONTMAN_ROOT}/libs/frontman-client/src/FrontmanClient__MCP__RemoteSchemaWorker.res.mjs`,
).href
childProcess.spawn = function(command, args = [], options = {}) {
  const allowedExecutable = process.env.FRONTMAN_CONFORMANCE_CLIENT_EXECUTABLE
  const allowedHarness = process.env.FRONTMAN_CONFORMANCE_CLIENT_HARNESS
  const serverUrl = args.at(-1)
  const allowed =
    allowedExecutable &&
    allowedHarness &&
    command === allowedExecutable &&
    args[0] === allowedHarness &&
    options.shell === true &&
    typeof serverUrl === "string" &&
    /^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?(?:\/mcp)?$/.test(serverUrl)
  if (!allowed || clientWorkerStarted) return deniedChildProcess()
  clientWorkerStarted = true
  const child = new EventEmitter()
  const worker = new OriginalWorker(pathToFileURL(process.env.FRONTMAN_CONFORMANCE_CLIENT_HARNESS_PATH), {
    argv: [serverUrl],
    env: {
      HOME: process.env.HOME,
      NODE_OPTIONS: process.env.NODE_OPTIONS,
      TMPDIR: process.env.TMPDIR,
      FRONTMAN_ROOT: process.env.FRONTMAN_ROOT,
      FRONTMAN_CONFORMANCE_CLIENT_EXECUTABLE: process.env.FRONTMAN_CONFORMANCE_CLIENT_EXECUTABLE,
      FRONTMAN_CONFORMANCE_CLIENT_HARNESS: process.env.FRONTMAN_CONFORMANCE_CLIENT_HARNESS,
      FRONTMAN_CONFORMANCE_CLIENT_HARNESS_PATH: process.env.FRONTMAN_CONFORMANCE_CLIENT_HARNESS_PATH,
      ...(options.env?.MCP_CONFORMANCE_SCENARIO === undefined
        ? {}
        : {MCP_CONFORMANCE_SCENARIO: options.env.MCP_CONFORMANCE_SCENARIO}),
      ...(options.env?.MCP_CONFORMANCE_CONTEXT === undefined
        ? {}
        : {MCP_CONFORMANCE_CONTEXT: options.env.MCP_CONFORMANCE_CONTEXT}),
    },
    stdout: true,
    stderr: true,
    resourceLimits: {maxOldGenerationSizeMb: 256, maxYoungGenerationSizeMb: 64},
  })
  child.stdout = worker.stdout
  child.stderr = worker.stderr
  child.kill = () => worker.terminate()
  worker.once("error", error => child.emit("error", error))
  worker.once("exit", status => child.emit("close", status))
  return child
}
childProcess.exec = deniedChildProcess
childProcess.execFile = deniedChildProcess
childProcess.execFileSync = deniedChildProcess
childProcess.execSync = deniedChildProcess
childProcess.fork = deniedChildProcess
childProcess.spawnSync = deniedChildProcess
workerThreads.Worker = class ConformanceWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const allowed =
      filename === schemaWorkerSource &&
      options.eval === true &&
      options.workerData?.url === schemaWorkerUrl &&
      schemaWorkerCount < 8
    if (!allowed) return deniedChildProcess()
    schemaWorkerCount += 1
    super(filename, {
      eval: true,
      workerData: {url: schemaWorkerUrl},
      resourceLimits: {maxOldGenerationSizeMb: 128, maxYoungGenerationSizeMb: 32},
    })
    this.once("exit", () => schemaWorkerCount -= 1)
  }
}
syncBuiltinESMExports()
