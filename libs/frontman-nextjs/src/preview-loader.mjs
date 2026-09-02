const parentOriginParam = "__frontman_parent_origin"
const channelParam = "__frontman_channel"
const storageParentOriginKey = "frontman.previewBridge.parentOrigin"
const storageChannelKey = "frontman.previewBridge.channel"

function isTrustedParentOrigin(origin) {
  try {
    const parsed = new URL(origin)
    const hostname = parsed.hostname.toLowerCase()
    return origin === window.location.origin ||
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname === "frontman.local" ||
      hostname.endsWith(".frontman.local") ||
      hostname === "frontman.sh" ||
      hostname.endsWith(".frontman.sh")
  } catch (_error) {
    return false
  }
}

function sessionGet(key) {
  try { return window.sessionStorage.getItem(key) } catch (_error) { return null }
}

function sessionSet(key, value) {
  try { window.sessionStorage.setItem(key, value) } catch (_error) {}
}

export function installFrontmanPreviewLoader(options = {}) {
  if (typeof window === "undefined" || typeof document === "undefined") return

  const installedAttribute = "data-frontman-preview-loader-installed"
  if (document.documentElement.hasAttribute(installedAttribute)) return
  document.documentElement.setAttribute(installedAttribute, "true")

  const basePath = options.basePath || "frontman"
  const bridgeUrl = options.bridgeUrl || `/${basePath}/preview-bridge.js`
  const params = new URLSearchParams(window.location.search)
  const parentOrigin = params.get(parentOriginParam) || sessionGet(storageParentOriginKey)
  const channel = params.get(channelParam) || sessionGet(storageChannelKey)

  if (!parentOrigin || !channel) return
  if (!isTrustedParentOrigin(parentOrigin)) {
    console.error("Frontman preview bridge rejected untrusted parent origin", { parentOrigin })
    return
  }

  sessionSet(storageParentOriginKey, parentOrigin)
  sessionSet(storageChannelKey, channel)

  if (params.has(parentOriginParam) || params.has(channelParam)) {
    params.delete(parentOriginParam)
    params.delete(channelParam)
    const cleanSearch = params.toString()
    const cleanUrl = window.location.pathname + (cleanSearch ? `?${cleanSearch}` : "") + window.location.hash
    window.history.replaceState(window.history.state, "", cleanUrl)
  }

  if (document.querySelector("script[data-frontman-bridge]")) return

  const script = document.createElement("script")
  script.src = bridgeUrl
  script.async = false
  script.setAttribute("data-frontman-bridge", "true")
  script.setAttribute("data-frontman-parent-origin", parentOrigin)
  script.setAttribute("data-frontman-channel", channel)
  script.onerror = function() {
    console.error("Frontman preview bridge script failed to load", { src: script.src })
  }
  document.head.appendChild(script)
}

installFrontmanPreviewLoader()
