

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

// Older browsers must still complete authentication if observation APIs are absent.
if (typeof IntersectionObserver === "function" &&
    typeof AbortSignal !== "undefined" && typeof AbortSignal.timeout === "function") {
  // Report only elements observed in a visible document, never an inferred render.
  const pageViewElements = new Set(document.querySelectorAll("[data-page-view-receipt]"))
  const pageViewObserver = new IntersectionObserver(entries => {
    if (document.visibilityState !== "visible") return
    for (const entry of entries) {
      if (!entry.isIntersecting || !pageViewElements.delete(entry.target)) continue
      pageViewObserver.unobserve(entry.target)
      fetch("/analytics/page-view", {
        method: "POST",
        credentials: "same-origin",
        headers: {"content-type": "application/json", "x-csrf-token": csrfToken},
        body: JSON.stringify({receipt: entry.target.dataset.pageViewReceipt}),
        keepalive: true,
        signal: AbortSignal.timeout(5000),
      }).catch(() => {
        // Analytics delivery must not interrupt sign-in or authorization.
      })
    }
  })
  const observePageViews = () => {
    if (document.visibilityState !== "visible") return
    for (const element of pageViewElements) {
      pageViewObserver.unobserve(element)
      pageViewObserver.observe(element)
    }
  }
  document.addEventListener("visibilitychange", observePageViews)
  observePageViews()
}

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
