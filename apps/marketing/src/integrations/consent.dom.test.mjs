import {JSDOM} from "jsdom"
import {afterEach, describe, expect, test} from "vitest"
import {createConsentScript} from "./consent.mjs"

const createPage = storedConsent => {
  const dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "https://frontman.sh/",
    runScripts: "outside-only",
    pretendToBeVisual: true,
  })
  const {window} = dom
  window.requestIdleCallback = callback => callback()
  window.setTimeout = callback => callback()
  if (storedConsent) {
    window.localStorage.setItem("frontman-cookie-consent", JSON.stringify(storedConsent))
  }
  window.eval(createConsentScript())
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"))
  return dom
}

const storedConsent = analytics => ({
  updatedAt: Date.now() - 1_000,
  expiresAt: Date.now() + 1_000,
  categories: {essential: true, analytics},
})

const pages = []

afterEach(() => {
  for (const page of pages.splice(0)) page.window.close()
})

describe("consent controls", () => {
  test("keeps all first-visit choices and one policy link in the compact banner", () => {
    const page = createPage()
    pages.push(page)
    const {document} = page.window
    const banner = document.getElementById("astro-consent-banner")

    expect(banner.querySelectorAll("button")).toHaveLength(3)
    expect(banner.querySelector(".cb-manage").textContent).toBe("Manage")
    expect(banner.querySelector(".cb-manage").getAttribute("aria-label")).toBe("Manage cookie preferences")
    expect(banner.querySelector(".cb-reject").textContent).toBe("Reject optional")
    expect(banner.querySelector(".cb-accept").textContent).toBe("Accept analytics")
    expect(banner.querySelectorAll('a[href="/privacy/"]')).toHaveLength(1)
    expect(page.window.astroConsent.get()).toBeNull()
    banner.querySelector(".cb-reject").click()
    expect(page.window.astroConsent.get().categories.analytics).toBe(false)
  })

  test("stores managed preferences and leaves a control to reopen them", () => {
    const page = createPage()
    pages.push(page)
    const {document, localStorage} = page.window

    document.querySelector(".cb-manage").click()
    const toggle = document.querySelector(".cb-toggle")
    toggle.click()
    document.querySelector("#astro-consent-modal .cb-accept").click()

    expect(JSON.parse(localStorage.getItem("frontman-cookie-consent")).categories).toEqual({
      essential: true,
      analytics: true,
    })
    const preferences = document.getElementById("astro-consent-preferences")
    expect(preferences).not.toBeNull()
    expect(document.activeElement).toBe(preferences)
  })

  test("reopens preferences with the stored analytics choice", () => {
    const page = createPage(storedConsent(true))
    pages.push(page)
    const {document} = page.window

    document.getElementById("astro-consent-preferences").click()

    expect(document.querySelector(".cb-toggle").getAttribute("aria-pressed")).toBe("true")
  })
})
