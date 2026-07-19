const runAnalytics = measurementId => {
  let analyticsLoaded = false

  window.dataLayer = window.dataLayer || []
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments)
  }

  window.gtag("consent", "default", {
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
    analytics_storage: "denied",
  })

  const currentCategories = () => window.astroConsent?.get()?.categories
  const analyticsAccepted = categories => categories?.analytics === true

  const loadAnalytics = () => {
    if (!measurementId || analyticsLoaded || !analyticsAccepted(currentCategories())) return
    analyticsLoaded = true

    const preconnect = document.createElement("link")
    preconnect.rel = "preconnect"
    preconnect.href = "https://www.googletagmanager.com"
    document.head.appendChild(preconnect)

    const script = document.createElement("script")
    script.async = true
    script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(measurementId)}`
    document.head.appendChild(script)

    window.gtag("js", new Date())
    window.gtag("config", measurementId, {
      anonymize_ip: true,
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
    })
  }

  const updateConsent = () => {
    const accepted = analyticsAccepted(currentCategories())
    window.gtag("consent", "update", {
      analytics_storage: accepted ? "granted" : "denied",
    })
    if (accepted) loadAnalytics()
  }

  window.trackEvent = (eventName, params) => {
    if (!analyticsLoaded || !analyticsAccepted(currentCategories())) return
    window.gtag("event", eventName, params)
  }

  const start = () => {
    updateConsent()
    document.body.addEventListener("click", event => {
      const target = event.target.closest?.("[data-ga-event]")
      if (!target) return
      window.trackEvent(target.getAttribute("data-ga-event"), {
        event_category: target.getAttribute("data-ga-category") || "engagement",
        event_label: target.getAttribute("data-ga-label") || "",
      })
    })
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, {once: true})
  } else {
    start()
  }
  document.addEventListener("consentchange", updateConsent)
}

export const createAnalyticsScript = measurementId => {
  const serializedMeasurementId = JSON.stringify(measurementId).replaceAll("<", "\\u003c")
  return `(${runAnalytics.toString()})(${serializedMeasurementId});`
}
