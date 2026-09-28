function isFrontmanRoute(path, basePath) {
  const prefix = `/${basePath.toLowerCase()}`
  return path === prefix || path.startsWith(`${prefix}/`) || path.endsWith(prefix) || path.endsWith(`${prefix}/`)
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

export function prependFrontmanRouteRewrite(server, basePath, trailingSlash) {
  const httpServer = server.httpServer
  if (!httpServer || trailingSlash === "ignore") return

  const listeners = httpServer.listeners("request").slice()
  httpServer.removeAllListeners("request")
  httpServer.on("request", request => {
    request.url = canonicalizeFrontmanUrl(request.url || "", basePath, trailingSlash)
  })
  for (const listener of listeners) httpServer.on("request", listener)
}
