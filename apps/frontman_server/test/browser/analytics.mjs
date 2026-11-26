import assert from "node:assert/strict"
import {chromium} from "playwright"

// Started by analytics_fixture.exs against an ephemeral local test database.
const base = new URL(process.argv[2])
assert(["localhost", "127.0.0.1"].includes(base.hostname), "Use a local test server")
const enabled = process.env.ANALYTICS_TEST_ENABLED === "true"
const requireVisibility = process.env.ANALYTICS_TEST_VISIBILITY === "true"
const deadline = setTimeout(() => {
  console.error("Hosted analytics browser scenario exceeded 45 seconds")
  process.exit(1)
}, 45000)
const browser = await chromium.launch({
  headless: !requireVisibility,
  ignoreDefaultArgs: ["--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding"],
})
try {
  const context = await browser.newContext({viewport: {width: 1440, height: 640}})
  const page = await context.newPage()
  const pageErrors = []
  const receipts = []
  page.on("pageerror", error => pageErrors.push(error.message))
  page.on("response", response => {
    if (new URL(response.url()).pathname === "/analytics/page-view") receipts.push(response)
  })
  const waitForReceiptCount = async count => {
    await page.waitForFunction(() => document.readyState === "complete")
    const until = Date.now() + 10000
    while (receipts.length < count && Date.now() < until) {
      await new Promise(resolve => setTimeout(resolve, 50))
    }
    assert.equal(receipts.length, count)
  }

  // A pending handoff safely returns to its checkpoint after normal password login.
  // Never submit the final authorization form: that would contact WorkOS.
  await page.goto(new URL("/auth/mcp/workos?external_auth_id=local-browser-fixture", base).href)
  await page.locator("#login-form").scrollIntoViewIfNeeded()
  if (enabled) await waitForReceiptCount(1)
  await page.locator("#login-form input[name='user[email]']").fill(process.env.ANALYTICS_TEST_EMAIL)
  await page.locator("#login-form input[name='user[password]']").fill(process.env.ANALYTICS_TEST_PASSWORD)
  await page.locator("#login-submit").click()
  await page.waitForURL("**/auth/mcp/workos/pending?*")
  await page.locator("#connect-account").waitFor({state: "visible"})
  await page.locator("#subscription-instructions").scrollIntoViewIfNeeded()
  assert.equal(await page.locator("#subscription-instructions").isVisible(), true)
  if (enabled) await waitForReceiptCount(3)
  else assert.equal(await page.locator("[data-page-view-receipt]").count(), 0)

  // Exercise actual intersections again without dispatching synthetic observer callbacks.
  await page.locator("#connect-account").scrollIntoViewIfNeeded()
  if (requireVisibility) {
    // Strict optional check for hosts with working native window visibility.
    // It fails rather than mocking document.visibilityState on unsupported hosts.
    const session = await context.newCDPSession(page)
    const {windowId} = await session.send("Browser.getWindowForTarget")
    await session.send("Browser.setWindowBounds", {windowId, bounds: {windowState: "minimized"}})
    await page.waitForFunction(() => document.visibilityState === "hidden", null, {
      timeout: 5000,
      polling: 50,
    })
    await session.send("Browser.setWindowBounds", {windowId, bounds: {windowState: "normal"}})
    await page.bringToFront()
    await page.waitForFunction(() => document.visibilityState === "visible")
  }
  await page.locator("#subscription-instructions").scrollIntoViewIfNeeded()
  await page.waitForTimeout(500)
  assert.equal(receipts.length, enabled ? 3 : 0, "Re-observation must not duplicate receipts")
  for (const response of receipts) {
    assert.equal(response.status(), 204)
    assert.deepEqual(Object.keys(response.request().postDataJSON()), ["receipt"])
  }
  assert.deepEqual(pageErrors, [])
  console.log(`Hosted authenticated checkpoint and billing instructions passed (analytics=${enabled})`)
  if (!requireVisibility) {
    console.log("Native hidden/visible transition not tested; set ANALYTICS_TEST_VISIBILITY=true for strict check")
  }
} finally {
  await browser.close()
  clearTimeout(deadline)
}
