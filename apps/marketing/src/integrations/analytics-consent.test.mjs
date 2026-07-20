import {JSDOM} from "jsdom"
import {afterEach, describe, expect, test} from "vitest"
import {createAnalyticsScript} from "./analytics-consent.mjs"

const createPage = ({analytics = false, globalPrivacyControl = false} = {}) => {
  const dom = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    url: "https://frontman.sh/",
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
})
