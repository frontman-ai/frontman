

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/frontman_server"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

const rootStyles = getComputedStyle(document.documentElement)
const topbarColor = rootStyles.getPropertyValue("--fm-color-primary").trim()
const topbarShadowColor = rootStyles.getPropertyValue("--fm-color-neutral-950").trim()

topbar.config({
  barColors: {0: topbarColor},
  shadowColor: topbarShadowColor,
})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

document.querySelectorAll("form[data-auto-submit]").forEach(form => {
  form.requestSubmit()
})

if (document.querySelector("[data-auto-close-window]")) {
  window.close()
}

const embeddedClientAuthCompletion = document.getElementById("embedded-client-auth-completion")
if (embeddedClientAuthCompletion && window.opener) {
  window.opener.postMessage(
    {
      type: "frontman.embeddedClient.authorized",
      version: 1,
      state: embeddedClientAuthCompletion.dataset.state,
      token: embeddedClientAuthCompletion.dataset.token,
    },
    embeddedClientAuthCompletion.dataset.origin,
  )
}

window.liveSocket = liveSocket

// Observation never authorizes an assistant or runs site tools.
const setup = document.getElementById("hosted-setup")
let setupSubmitting = false
if (setup) {
  let timer
  let request
  let disposed = false
  const deadline = Date.now() + 10 * 60 * 1000
  const message = document.getElementById("setup-observation")
  const poll = async () => {
    clearTimeout(timer)
    if (disposed || document.hidden || request) return
    if (Date.now() >= deadline) {
      message.textContent = "Automatic checks paused. Refresh setup status when you are ready."
      return
    }
    request = new AbortController()
    const timeout = setTimeout(() => request?.abort(), 5000)
    try {
      const response = await fetch(setup.dataset.setupStatusUrl, {
        credentials: "same-origin", headers: {accept: "text/html"},
        signal: request.signal, cache: "no-store",
      })
      if (!response.ok || response.redirected) throw new Error("Session unavailable")
      const status = await response.json()
      if (disposed || setupSubmitting) return
      if (status.expired || status.revision !== setup.dataset.setupRevision) {
        disposed = true
        window.location.assign(setup.dataset.setupPageUrl)
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        message.textContent = "Could not check setup. We will retry; you can also refresh setup status."
      }
    } finally {
      clearTimeout(timeout)
      request = null
      if (!disposed && !document.hidden) timer = setTimeout(poll, 5000)
    }
  }
  document.addEventListener("visibilitychange", () => {
    clearTimeout(timer)
    if (document.hidden) request?.abort()
    else poll()
  })
  window.addEventListener("pagehide", () => {
    disposed = true
    clearTimeout(timer)
    request?.abort()
  })
  window.addEventListener("pageshow", event => {
    if (event.persisted) { disposed = false; poll() }
  })
  document.addEventListener("submit", event => {
    if (!event.target.matches("form[data-once-submit], #connect-switch-account")) return
    disposed = true
    clearTimeout(timer)
    request?.abort()
  })
  timer = setTimeout(poll, 5000)
}

document.querySelectorAll("form[data-once-submit]").forEach(form => {
  form.addEventListener("submit", event => {
    if (setupSubmitting) { event.preventDefault(); return }
    setupSubmitting = true
    document.querySelectorAll("form[data-once-submit] button").forEach(button => { button.disabled = true })
  })
})
window.addEventListener("pageshow", () => {
  setupSubmitting = false
  document.querySelectorAll("form[data-once-submit] button").forEach(button => { button.disabled = false })
})

document.querySelector("form[data-site-launch]")?.addEventListener("submit", event => {
  event.preventDefault()
  const form = event.currentTarget
  const error = form.querySelector("[data-site-launch-error]")
  try {
    const site = new URL(new FormData(form).get("site_url"))
    if (site.protocol !== "https:" || !site.hostname || site.username ||
        site.password || site.search || site.hash) throw new Error("Invalid site URL")
    const basePath = site.pathname.replace(/\/(?:wp-admin(?:\/.*)?|frontman)\/?$/, "").replace(/\/$/, "")
    if (event.submitter?.value === "open") {
      site.pathname = basePath + "/frontman"
      site.searchParams.set("frontman_intent", "assistant")
    } else {
      site.pathname = basePath + "/wp-admin/plugin-install.php"
      site.searchParams.set("tab", "plugin-information")
      site.searchParams.set("plugin", "frontman-agentic-ai-editor")
    }
    error.hidden = true
    window.open(site.href, "_blank", "noopener,noreferrer")
  } catch {
    error.hidden = false
  }
})

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
