function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function jsonSafe(value) {
  if (value === undefined || typeof value === "function") return undefined

  try {
    return JSON.parse(JSON.stringify(value))
  } catch {
    return undefined
  }
}

function named(value) {
  return typeof value?.name === "string" ? value.name : undefined
}

function pluginSummary(plugins) {
  if (!Array.isArray(plugins)) return undefined

  return {
    count: plugins.length,
    names: plugins
      .map((plugin) => {
        if (typeof plugin === "string") return plugin
        if (Array.isArray(plugin)) return named(plugin[0]) ?? (typeof plugin[0] === "string" ? plugin[0] : undefined)
        return named(plugin)
      })
      .filter(Boolean),
  }
}

function sanitizeMarkdown(markdown) {
  if (!isPlainObject(markdown)) return undefined

  const out = {}
  for (const key of ["syntaxHighlight", "shikiConfig", "gfm", "remarkRehype"]) {
    const value = jsonSafe(markdown[key])
    if (value !== undefined) out[key] = value
  }

  const remarkPlugins = pluginSummary(markdown.remarkPlugins)
  if (remarkPlugins) out.remarkPlugins = remarkPlugins

  const rehypePlugins = pluginSummary(markdown.rehypePlugins)
  if (rehypePlugins) out.rehypePlugins = rehypePlugins

  if (markdown.processor) out.processor = "configured"

  return Object.keys(out).length ? out : undefined
}

function sanitizeImage(image) {
  if (!isPlainObject(image)) return undefined

  const out = {}
  for (const key of ["endpoint", "domains", "remotePatterns", "responsiveStyles", "layout", "objectFit", "objectPosition"]) {
    const value = jsonSafe(image[key])
    if (value !== undefined) out[key] = value
  }

  if (isPlainObject(image.service)) {
    const service = {}
    const entrypoint = jsonSafe(image.service.entrypoint)
    if (entrypoint !== undefined) service.entrypoint = entrypoint

    const config = jsonSafe(image.service.config)
    if (config !== undefined) service.config = config

    if (Object.keys(service).length) out.service = service
  }

  return Object.keys(out).length ? out : undefined
}

function sanitizeSession(session) {
  if (!isPlainObject(session)) return undefined

  const out = {}
  for (const key of ["driver", "ttl", "cookie"]) {
    const value = jsonSafe(session[key])
    if (value !== undefined) out[key] = value
  }
  return Object.keys(out).length ? out : undefined
}

function pickSafeObject(value, keys) {
  if (!isPlainObject(value)) return undefined

  const out = {}
  for (const key of keys) {
    const safe = jsonSafe(value[key])
    if (safe !== undefined) out[key] = safe
  }
  return Object.keys(out).length ? out : undefined
}

export function sanitizeResolvedAstroConfig({ astroVersion, buildOutput, config }) {
  return {
    astroVersion,
    buildOutput,
    output: typeof config.output === "string" ? config.output : undefined,
    adapter: named(config.adapter),
    integrations: Array.isArray(config.integrations) ? config.integrations.map(named).filter(Boolean) : [],
    site: typeof config.site === "string" ? config.site : undefined,
    base: typeof config.base === "string" ? config.base : "/",
    trailingSlash: config.trailingSlash ?? "ignore",
    redirects: jsonSafe(config.redirects),
    i18n: jsonSafe(config.i18n),
    image: sanitizeImage(config.image),
    markdown: sanitizeMarkdown(config.markdown),
    security: pickSafeObject(config.security, ["checkOrigin", "allowedDomains", "actionBodySizeLimit", "serverIslandBodySizeLimit", "csp"]),
    session: sanitizeSession(config.session),
    server: pickSafeObject(config.server, ["allowedHosts"]),
  }
}
