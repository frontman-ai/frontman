import {JSDOM} from "jsdom"
import {afterEach, describe, expect, test} from "vitest"
import {createAnalyticsScript} from "./analytics-consent.mjs"

const createPage = ({analytics = false, globalPrivacyControl = false, url = "https://frontman.sh/"} = {}) => {
  const dom = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    url,
    runScripts: "outside-only",
  })
  const {window} = dom
  let categories = {essential: true, analytics}
  window.astroConsent = {get: () => ({categories})}
  Object.defineProperty(window.navigator, "globalPrivacyControl", {
    configurable: true,
    value: globalPrivacyControl,
  })
  window.eval(createAnalyticsScript("G-TEST"))
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"))
  return {
    dom,
    setCategories: nextCategories => {
      categories = nextCategories
      window.document.dispatchEvent(
        new window.CustomEvent("consentchange", {detail: nextCategories}),
      )
    },
  }
}

const pages = []

afterEach(() => {
  for (const page of pages.splice(0)) page.window.close()
})

describe("analytics consent", () => {
  test.each([
    "http://localhost:4321/",
    "http://127.0.0.1:4321/",
    "http://[::1]:4321/",
    "https://preview.frontman-marketing.pages.dev/",
    "https://frontman.sh.example.com/",
  ])("does not collect on non-production hosts even with consent: %s", url => {
    const {dom, setCategories} = createPage({analytics: true, url})
    pages.push(dom)
    setCategories({essential: true, analytics: true})
    dom.window.trackEvent("install_intent", {})

    expect(dom.window.document.querySelector("script[src*='googletagmanager.com']")).toBeNull()
    expect(dom.window.document.querySelector("link[rel='preconnect']")).toBeNull()
    expect(dom.window.dataLayer.map(args => args[0])).not.toContain("config")
    expect(dom.window.dataLayer.map(args => args[0])).not.toContain("event")
  })

  test("does not replay unconsented events or initialize twice after reacceptance", () => {
    const {dom, setCategories} = createPage()
    pages.push(dom)
    const events = () => dom.window.dataLayer.map(args => Array.from(args)).filter(args => args[0] === "event")

    dom.window.trackEvent("before_acceptance")
    setCategories({essential: true, analytics: true})
    expect(events()).toEqual([])
    dom.window.trackEvent("accepted")
    setCategories({essential: true, analytics: false})
    dom.window.trackEvent("revoked")
    setCategories({essential: true, analytics: true})

    expect(events().map(args => args[1])).toEqual(["accepted"])
    expect(dom.window.document.querySelectorAll("script[src*='googletagmanager.com']")).toHaveLength(1)
    expect(dom.window.dataLayer.filter(args => args[0] === "config")).toHaveLength(1)
  })

  test("does not load analytics without explicit consent", () => {
    const {dom} = createPage()
    pages.push(dom)

    expect(dom.window.document.querySelector("script[src*='googletagmanager.com']")).toBeNull()
  })

  test("loads analytics after explicit consent even when GPC is enabled", () => {
    const {dom, setCategories} = createPage({globalPrivacyControl: true})
    pages.push(dom)

    setCategories({essential: true, analytics: true})

    expect(dom.window.document.querySelector("script[src*='googletagmanager.com']")).not.toBeNull()
  })

  test("updates Google consent mode when analytics consent is revoked", () => {
    const {dom, setCategories} = createPage({analytics: true})
    pages.push(dom)

    setCategories({essential: true, analytics: false})

    const consentUpdates = dom.window.dataLayer
      .map(args => Array.from(args))
      .filter(args => args[0] === "consent" && args[1] === "update")
    expect(consentUpdates.at(-1)[2]).toEqual({analytics_storage: "denied"})
  })

  test("tracks privacy-safe acquisition dimensions from CTA links", () => {
    const {dom} = createPage({analytics: true})
    pages.push(dom)

    const link = dom.window.document.createElement("a")
    link.href = "https://wordpress.org/plugins/frontman-agentic-ai-editor/"
    link.dataset.gaEvent = "wordpress_article_cta_clicked"
    link.dataset.gaCategory = "conversion"
    link.dataset.gaLabel = "after_demo"
    link.dataset.gaPlacement = "after_demo"
    link.dataset.gaDestination = "wordpress_org"
    link.dataset.gaTaskFamily = "update"
    link.innerHTML = "<span>Install Frontman</span>"
    dom.window.document.body.appendChild(link)

    link.querySelector("span").dispatchEvent(
      new dom.window.MouseEvent("click", {bubbles: true}),
    )

    const events = dom.window.dataLayer
      .map(args => Array.from(args))
      .filter(args => args[0] === "event")
    expect(events.at(-1)).toEqual([
      "event",
      "wordpress_article_cta_clicked",
      {
        event_category: "conversion",
        event_label: "after_demo",
        page_path: "/",
        placement: "after_demo",
        destination: "wordpress_org",
        task_family: "update",
      },
    ])
  })
})
