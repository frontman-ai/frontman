import assert from "node:assert/strict"
import {chromium} from "playwright"
import {signInFixture} from "./fixture-auth.mjs"

const base = new URL(process.argv[2])
assert(["localhost", "127.0.0.1"].includes(base.hostname), "Local preview only")
const cases = JSON.parse(process.env.ONBOARDING_PREVIEW_CASES)
const browser = await chromium.launch({headless: false})
const closed = new Promise(resolve => browser.once("disconnected", resolve))
const entry = new URL("/auth/mcp/workos?external_auth_id=local-onboarding-preview", base)

async function screen(label, scenario, suffix = "") {
  const context = await browser.newContext({viewport: null})
  await context.route("**/*", async route => {
    const url = new URL(route.request().url())
    if (url.origin === base.origin) {
      if (!["/auth/mcp/workos/pending", "/wordpress/connect/checkout", "/wordpress/connect/portal"].includes(url.pathname)
          || route.request().method() !== "POST") return route.continue()
    }
    if (!route.request().isNavigationRequest()) return route.abort()
    return route.fulfill({
      status: 200,
      contentType: "text/html",
      body: "<title>Local preview boundary</title><h1>Local preview only</h1><p>This action normally opens sign-in, WordPress, payment, or assistant authorization. It is disabled here. No external request was sent.</p><p>Use your browser’s Back button to continue exploring.</p>",
    })
  })
  const page = await context.newPage()
  await page.goto(entry.href)
  await page.locator("#google-login-form").waitFor()
  if (scenario) {
    await signInFixture(page, base, scenario.email, process.env.ONBOARDING_TEST_PASSWORD)
    await page.locator("#hosted-setup").waitFor()
    if (scenario.name === "trial-offer") {
      await page.locator("#connect-select-site select").selectOption(scenario.site_ids[0])
      await page.locator("#connect-select-site button").click()
      await page.locator("#checkout-plan").waitFor()
    }
  }
  if (suffix) {
    const url = new URL(page.url())
    url.searchParams.set("checkout", suffix)
    await page.goto(url.href)
  }
  await page.evaluate(label => { document.title = `Preview: ${label}` }, label)
  console.log(`OPEN: ${label} — ${page.url()}`)
  return page
}

try {
  await screen("Plan without another trial", cases.find(c => c.name === "returning"))
  await screen("Choose an existing site", cases.find(c => c.name === "choose-site"))
  await screen("Continue to your assistant", cases.find(c => c.name === "ready"))
  await screen("Waiting for payment", cases.find(c => c.name === "trial-offer"), "success")
  await screen("Choose a trial / plan", cases.find(c => c.name === "trial-offer"))
  await screen("Connect your WordPress site", cases.find(c => c.name === "new-site"))
  await screen("Sign in — appearance only", null)
  console.log("PREVIEW READY: independent browser windows; close the browser to finish.")
  await closed
} finally {
  await browser.close()
}
