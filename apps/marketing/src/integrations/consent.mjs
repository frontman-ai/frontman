// Adapted from astro-consent, Copyright (c) 2026 Velohost UK Limited.
// Licensed under MIT; see THIRD_PARTY_LICENSES.md.

const config = {
  storageKey: "frontman-cookie-consent",
  ttl: 180 * 24 * 60 * 60 * 1000,
  idleDelay: 1000,
  headline: "Cookie preferences",
  description: "Optional analytics cookies measure site traffic.",
  privacyPolicyUrl: "/privacy/",
}

const runConsent = config => {
  let memoryConsent = null
  const advertisingEnabled = config.advertisingEnabled && location.origin === "https://frontman.sh"
  let advertisingQueue = Promise.resolve()
  const syncAdvertising = (explicit, current = read()) => {
    if (!advertisingEnabled) return Promise.resolve()
    const allowed = current?.categories.advertising === true
    const oppref = allowed ? new URL(location.href).searchParams.get("oppref") : null
    if (allowed && !explicit && !oppref) return advertisingQueue
    advertisingQueue = advertisingQueue.catch(() => {}).then(async () => {
      const response = await fetch("https://api.frontman.sh/ads/attribution", {
        method: allowed ? "POST" : "DELETE",
        credentials: "include",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(allowed ? {
          advertising_consent: true, oppref,
          consent_updated_at_ms: current.updatedAt,
        } : {}),
      })
      if (response.status !== 204) throw new Error("Advertising update failed")
    })
    advertisingQueue.catch(() => {
      const button = document.getElementById("astro-consent-preferences")
      if (button) button.textContent = "Advertising update failed — save preferences to retry"
    })
    return advertisingQueue
  }

  const read = () => {
    let raw
    try {
      raw = localStorage.getItem(config.storageKey)
    } catch (_error) {
      return memoryConsent
    }
    if (!raw) return memoryConsent

    try {
      const consent = JSON.parse(raw)
      if (
        typeof consent !== "object" ||
        consent === null ||
        typeof consent.updatedAt !== "number" ||
        typeof consent.expiresAt !== "number" ||
        consent.expiresAt <= Date.now() ||
        typeof consent.categories !== "object" ||
        consent.categories === null
      ) {
        localStorage.removeItem(config.storageKey)
        memoryConsent = null
        return null
      }
      const normalized = {
        updatedAt: consent.updatedAt,
        expiresAt: consent.expiresAt,
        categories: {
          essential: true,
          analytics: consent.categories.analytics === true,
          ...(advertisingEnabled ? {advertising: consent.categories.advertising === true} : {}),
        },
      }
      memoryConsent = normalized
      if (JSON.stringify(consent) !== JSON.stringify(normalized)) {
        try {
          localStorage.setItem(config.storageKey, JSON.stringify(normalized))
        } catch (_storageError) {}
      }
      return normalized
    } catch (_error) {
      try {
        localStorage.removeItem(config.storageKey)
      } catch (_storageError) {}
      memoryConsent = null
      return null
    }
  }

  const set = categories => {
    const allowedCategories = {
      essential: true,
      analytics: categories?.analytics === true,
      ...(advertisingEnabled ? {advertising: categories?.advertising === true} : {}),
    }
    const now = Date.now()
    const consent = {
      updatedAt: now,
      expiresAt: now + config.ttl,
      categories: allowedCategories,
    }
    memoryConsent = consent
    try {
      localStorage.setItem(config.storageKey, JSON.stringify(consent))
    } catch (_error) {
      if (advertisingEnabled) {
        allowedCategories.advertising = false
        try { localStorage.removeItem(config.storageKey) } catch (_storageError) {}
      }
    }
    syncAdvertising(true, consent)
    document.dispatchEvent(new CustomEvent("consentchange", {detail: allowedCategories}))
    return allowedCategories
  }

  window.astroConsent = {
    get: read,
    set,
    reset: () => {
      const clear = () => {
        memoryConsent = null
        try { localStorage.removeItem(config.storageKey) } catch (_error) {}
        location.reload()
      }
      if (!advertisingEnabled) return clear()
      set({analytics: false, advertising: false})
      return syncAdvertising(true).then(clear).catch(() => {})
    },
  }

  const createElement = (tagName, className, text) => {
    const element = document.createElement(tagName)
    if (className) element.className = className
    if (text) element.textContent = text
    return element
  }

  const createButton = (className, text) => {
    const button = createElement("button", className, text)
    button.type = "button"
    return button
  }

  const appendDescription = parent => {
    parent.append(`${config.description} Read our `)
    const privacyLink = createElement("a", "", "Privacy policy")
    privacyLink.href = config.privacyPolicyUrl
    parent.append(privacyLink, ".")
  }

  const removeBanner = () => document.getElementById("astro-consent-banner")?.remove()

  const openModal = () => {
    if (document.getElementById("astro-consent-modal")) return

    const previousOverflow = document.body.style.overflow
    const previousFocus = document.activeElement
    const state = {
      analytics: read()?.categories.analytics === true,
      advertising: read()?.categories.advertising === true,
    }
    const modal = createElement("div")
    modal.id = "astro-consent-modal"
    modal.setAttribute("role", "dialog")
    modal.setAttribute("aria-modal", "true")
    modal.setAttribute("aria-labelledby", "astro-consent-title")

    const panel = createElement("div", "cb-modal")
    const header = createElement("div", "cb-modal-header")
    const title = createElement("h3", "", config.headline)
    title.id = "astro-consent-title"
    const description = createElement("p")
    appendDescription(description)
    header.append(title, description)

    const categories = createElement("div", "cb-panel")
    const essentialRow = createElement("div", "cb-row")
    essentialRow.append(
      createElement("span", "", "Essential"),
      createElement("strong", "", "Always on"),
    )
    const analyticsRow = createElement("div", "cb-row")
    const analyticsToggle = createButton("cb-toggle", "")
    analyticsToggle.setAttribute("aria-label", "Allow analytics cookies")
    analyticsToggle.classList.toggle("active", state.analytics)
    analyticsToggle.setAttribute("aria-pressed", String(state.analytics))
    analyticsToggle.onclick = () => {
      state.analytics = !state.analytics
      analyticsToggle.classList.toggle("active", state.analytics)
      analyticsToggle.setAttribute("aria-pressed", String(state.analytics))
    }
    analyticsRow.append(createElement("span", "", "Analytics"), analyticsToggle)
    categories.append(essentialRow, analyticsRow)
    if (advertisingEnabled) {
      const row = createElement("div", "cb-row")
      const toggle = createButton("cb-toggle", "")
      toggle.setAttribute("aria-label", "Allow advertising measurement")
      const update = () => {
        toggle.classList.toggle("active", state.advertising)
        toggle.setAttribute("aria-pressed", String(state.advertising))
      }
      toggle.onclick = () => { state.advertising = !state.advertising; update() }
      update()
      row.append(createElement("span", "", "Advertising measurement (OpenAI)"), toggle)
      categories.append(row)
    }

    const actions = createElement("div", "cb-actions cb-actions-modal")
    const reject = createButton("cb-reject", "Reject optional")
    const accept = createButton("cb-accept", "Save preferences")
    actions.append(reject, accept)
    panel.append(header, categories, actions)
    modal.append(panel)

    const close = () => {
      document.removeEventListener("keydown", onKeyDown)
      modal.remove()
      document.body.style.overflow = previousOverflow
      const focusTarget = previousFocus !== document.body && previousFocus?.isConnected
        ? previousFocus
        : document.getElementById("astro-consent-preferences")
      if (typeof focusTarget?.focus === "function") focusTarget.focus()
    }

    const finish = (analytics, advertising = false) => {
      set({analytics, advertising})
      removeBanner()
      ensurePreferencesButton()
      close()
    }

    const onKeyDown = event => {
      if (event.key === "Escape") {
        event.preventDefault()
        close()
        return
      }
      if (event.key !== "Tab") return

      const focusable = Array.from(modal.querySelectorAll("button, [href], [tabindex]"))
        .filter(element => !element.hasAttribute("disabled") && element.tabIndex !== -1)
      if (focusable.length === 0) {
        event.preventDefault()
        return
      }
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }

    reject.onclick = () => finish(false)
    accept.onclick = () => finish(state.analytics, state.advertising)
    modal.onclick = event => {
      if (event.target === modal) close()
    }
    document.addEventListener("keydown", onKeyDown)
    document.body.style.overflow = "hidden"
    document.body.append(modal)
    requestAnimationFrame(() => modal.classList.add("cb-visible"))
    accept.focus()
  }

  const ensurePreferencesButton = () => {
    if (document.getElementById("astro-consent-preferences")) return
    const button = createButton("cb-preferences", "Cookie preferences")
    button.id = "astro-consent-preferences"
    button.onclick = openModal
    document.body.append(button)
  }

  const start = () => {
    if (read()) {
      ensurePreferencesButton()
      return
    }
    if (document.getElementById("astro-consent-banner")) return

    const banner = createElement("div")
    banner.id = "astro-consent-banner"
    banner.className = "cb-mode-banner"
    banner.setAttribute("role", "dialog")
    banner.setAttribute("aria-label", "Cookie consent")
    banner.setAttribute("aria-live", "polite")

    const container = createElement("div", "cb-container")
    const copy = createElement("div")
    copy.append(createElement("div", "cb-title", config.headline))
    const description = createElement("div", "cb-desc")
    appendDescription(description)
    copy.append(description)

    const actions = createElement("div", "cb-actions")
    const manage = createButton("cb-manage", "Manage")
    manage.setAttribute("aria-label", "Manage cookie preferences")
    const reject = createButton("cb-reject", "Reject optional")
    const accept = createButton("cb-accept", "Accept analytics")
    manage.onclick = openModal
    reject.onclick = () => {
      set({analytics: false})
      banner.remove()
      ensurePreferencesButton()
    }
    accept.onclick = () => {
      set({analytics: true})
      banner.remove()
      ensurePreferencesButton()
    }
    actions.append(manage, reject, accept)
    container.append(copy, actions)
    banner.append(container)
    document.body.append(banner)
    requestAnimationFrame(() => banner.classList.add("cb-visible"))
  }

  const schedule = () => {
    if (typeof window.requestIdleCallback === "function") {
      window.requestIdleCallback(() => window.setTimeout(start, config.idleDelay), {timeout: 2000})
    } else {
      window.setTimeout(start, 300 + config.idleDelay)
    }
  }

  syncAdvertising(false)
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule, {once: true})
  } else {
    schedule()
  }
}

export const createConsentScript = ({advertisingEnabled = false} = {}) => {
  const serializedConfig = JSON.stringify({...config, advertisingEnabled}).replaceAll("<", "\\u003c")
  return `(${runConsent.toString()})(${serializedConfig});`
}

export default function consent(options) {
  return {
    name: "frontman-marketing-consent",
    hooks: {
      "astro:config:setup": ({injectScript}) => injectScript("page", createConsentScript(options)),
    },
  }
}
