function isFrontmanRoute(path, basePath) {
  const prefix = `/${basePath.toLowerCase()}`
  return path === prefix || path.startsWith(`${prefix}/`) || path.endsWith(prefix) || path.endsWith(`${prefix}/`)
}

const exactMcpRequests = new WeakSet()
const internalMcpPath = "/__frontman_exact_mcp"

export function prepareFrontmanRequest(request, basePath, trailingSlash, mcpEnabled) {
  const rawUrl = request.url || ""
  const queryIndex = rawUrl.indexOf("?")
  const path = queryIndex === -1 ? rawUrl : rawUrl.slice(0, queryIndex)
  const query = queryIndex === -1 ? "" : rawUrl.slice(queryIndex)
  if (path === "/mcp" && mcpEnabled) {
    exactMcpRequests.add(request)
    request.url = `${internalMcpPath}${query}`
    return
  }
  request.url = canonicalizeFrontmanUrl(rawUrl, basePath, trailingSlash)
}

export function isExactMcpRequest(request) {
  return exactMcpRequests.has(request)
}

export function canonicalizeFrontmanUrl(rawUrl, basePath, trailingSlash) {
  if (!rawUrl || trailingSlash === "ignore") return rawUrl

  const queryIndex = rawUrl.indexOf("?")
  const path = queryIndex === -1 ? rawUrl : rawUrl.slice(0, queryIndex)
  if (!isFrontmanRoute(path.toLowerCase(), basePath)) return rawUrl

  const query = queryIndex === -1 ? "" : rawUrl.slice(queryIndex)
  switch (trailingSlash) {
    case "always":
      return path.endsWith("/") ? rawUrl : `${path}/${query}`
    case "never":
      return path.endsWith("/") ? `${path.slice(0, -1)}${query}` : rawUrl
    default:
      return rawUrl
  }
}

export function prependFrontmanRouteRewrite(server, basePath, trailingSlash, mcpEnabled) {
  const httpServer = server.httpServer
  if (!httpServer || trailingSlash === "ignore") return

  const listeners = httpServer.listeners("request").slice()
  httpServer.removeAllListeners("request")
  httpServer.on("request", request => {
    prepareFrontmanRequest(request, basePath, trailingSlash, mcpEnabled)
  })
  for (const listener of listeners) httpServer.on("request", listener)
}
