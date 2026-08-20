import {pathToFileURL} from "node:url"

const root = process.env.FRONTMAN_ROOT
if (!root) throw new Error("FRONTMAN_ROOT is required")

await import(pathToFileURL(`${root}/libs/frontman-client/test/setup.mjs`))

const originalFetch = globalThis.fetch
globalThis.fetch = async (...args) => {
  const response = await originalFetch(...args)
  if (!response.headers.get("content-type")?.includes("application/json")) return response
  const json = await response.clone().json()
  const serverInfo = json?.result?.serverInfo
  if (!serverInfo || json.result?._meta?.["io.modelcontextprotocol/serverInfo"]) return response
  json.result._meta = {
    ...json.result._meta,
    "io.modelcontextprotocol/serverInfo": serverInfo,
  }
  delete json.result.serverInfo
  return new Response(JSON.stringify(json), {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers,
  })
}

const Client = await import(
  pathToFileURL(`${root}/libs/frontman-client/src/FrontmanClient__MCP__Client.res.mjs`)
)

const scenario = process.env.MCP_CONFORMANCE_SCENARIO
const context = JSON.parse(process.env.MCP_CONFORMANCE_CONTEXT ?? "{}")
const serverUrl = process.argv.at(-1)
const baseUrl = serverUrl.endsWith("/mcp") ? serverUrl.slice(0, -4) : serverUrl
const client = Client.make(baseUrl)

const requireOk = (result, operation) => {
  if (result.TAG !== "Ok") throw new Error(`${operation}: ${result._0}`)
  return result._0
}

switch (scenario === "request-metadata") {
case true:
  requireOk(await Client.fetchDiscovery(client), "discovery")
  break
case false:
  requireOk(await Client.connect(client), "connect")
  switch (scenario) {
    case "tools_call":
      requireOk(await Client.executeTool(client, "add_numbers", {a: 7, b: 8}), "add_numbers")
      break
    case "http-standard-headers":
      requireOk(await Client.executeTool(client, "test_headers", {}), "test_headers")
      break
    case "http-custom-headers":
      for (const call of context.toolCalls ?? []) {
        const argumentsWithoutNull = Object.fromEntries(
          Object.entries(call.arguments).filter(([, value]) => value !== null),
        )
        requireOk(await Client.executeTool(client, call.name, argumentsWithoutNull), call.name)
      }
      break
    case "http-invalid-tool-headers":
      requireOk(await Client.executeTool(client, "valid_tool", {region: "us-west1"}), "valid_tool")
      break
    case "json-schema-ref-no-deref":
      break
    default:
      throw new Error(`Unsupported MCP conformance client scenario: ${scenario}`)
  }
}

Client.disconnect(client)
