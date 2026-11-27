import assert from "node:assert/strict"
import {createHmac} from "node:crypto"
import {mkdir} from "node:fs/promises"
import path from "node:path"
import {chromium} from "playwright"
import {signInFixture} from "./fixture-auth.mjs"

const base = new URL(process.argv[2])
assert(["localhost", "127.0.0.1"].includes(base.hostname), "Use a local test server")
const scenario = process.env.ONBOARDING_CASE
const directory = process.env.ONBOARDING_SCREENSHOT_DIR
const siteIds = JSON.parse(process.env.ONBOARDING_SITE_IDS || "[]")
const deadline = setTimeout(() => {
  console.error("Onboarding browser scenario exceeded 60 seconds")
  process.exit(1)
}, 60000)

const browser = await chromium.launch()
let video
let context
try {
  const recording = directory && scenario === "trial-offer"
  context = await browser.newContext({
    viewport: {width: 1360, height: 1000},
    recordVideo: recording ? {dir: directory, size: {width: 1360, height: 1000}} : undefined,
  })
  const page = await context.newPage()
  video = page.video()
  const errors = []
  page.on("pageerror", error => errors.push(error.message))

  const capture = async name => {
    if (!directory) return
    await mkdir(directory, {recursive: true})
    await page.evaluate(() => document.fonts.ready)
    await page.screenshot({path: path.join(directory, `${name}.png`), fullPage: true, animations: "disabled"})
  }

  await page.goto(new URL("/auth/mcp/workos?external_auth_id=local-onboarding-fixture", base).href)
  await page.locator("#google-login-form").waitFor()
  assert.equal(await page.locator("#github-login-form").count(), 1)
  assert.equal(await page.locator("#login-form, #email-link-form, input[type=password]").count(), 0)
  assert.equal(await page.getByText("Confirm your account", {exact: true}).count(), 0)
  assert.equal(await page.getByText("Enter the runtime era.", {exact: true}).count(), 0)
  if (scenario === "new-site") await capture("01-sign-in")
  if (recording) await page.waitForTimeout(600)

  await signInFixture(page, base, process.env.ONBOARDING_TEST_EMAIL, process.env.ONBOARDING_TEST_PASSWORD)
  await page.waitForURL("**/auth/mcp/workos/pending?*")
  await page.locator("#hosted-setup").waitFor()

  switch (scenario) {
    case "new-site":
      await page.locator("#connect-no-sites").waitFor()
      assert.equal(await page.locator("#connect-continue").count(), 0)
      assert.equal(await page.locator("#connect-site-launch input[type=url]").count(), 1)
      await capture("02-connect-wordpress")
      break
    case "trial-offer": {
      await page.locator("#connect-selected-site").waitFor()
      await page.locator("#checkout-plan").waitFor()
      assert.match(await page.locator("#checkout-plan").innerText(), /trial/i)
      assert.equal(await page.locator("#checkout-submit").count(), 1)
      assert.equal(await page.locator("#checkout-plan input[name=interval]").count(), 2)
      await page.locator("#checkout-plan input[value=yearly]").check()
      assert.equal(await page.locator("#checkout-plan input[value=yearly]").isChecked(), true)
      if (recording) await page.waitForTimeout(800)
      await page.locator("#checkout-plan input[value=monthly]").check()
      assert.equal(await page.locator("#connect-continue").count(), 0)
      await capture("06-trial-offer")

      // A return URL is not payment proof. No external checkout is performed here.
      const returned = new URL(page.url())
      returned.searchParams.set("checkout", "success")
      await page.goto(returned.href)
      await page.locator("#checkout-pending").waitFor()
      assert.equal(await page.locator("#connect-continue").count(), 0)
      assert.equal(await page.locator("#checkout-plan").count(), 0)
      await capture("08-waiting-for-payment-confirmation")

      // Exercise the actual signed webhook and browser polling. This fixture is
      // local-only; no payment provider response or browser request is mocked.
      const userId = process.env.ONBOARDING_USER_ID
      const now = Math.floor(Date.now() / 1000)
      const payload = JSON.stringify({
        id: `evt_onboarding_${userId}`,
        type: "customer.subscription.created",
        data: {object: {
          id: `sub_onboarding_${userId}`,
          customer: `cus_onboarding_${userId}`,
          status: "trialing",
          metadata: {user_id: userId},
          trial_end: now + 7 * 86400,
          current_period_end: now + 7 * 86400,
          items: {data: [{price: {id: "price_monthly_test", recurring: {interval: "month"}}}]},
        }},
      })
      const signature = createHmac("sha256", process.env.ONBOARDING_WEBHOOK_SECRET)
        .update(`${now}.${payload}`).digest("hex")
      const webhook = await page.request.post(new URL("/api/stripe/webhook", base).href, {
        headers: {"content-type": "application/json", "stripe-signature": `t=${now},v1=${signature}`},
        data: payload,
      })
      assert.equal(webhook.status(), 200)
      await page.locator("#connect-continue").waitFor({state: "visible", timeout: 15000})
      assert.equal(await page.locator("#connect-access").count(), 0)
      assert.equal(new URL(page.url()).searchParams.has("checkout"), false)
      if (recording) await page.waitForTimeout(1000)
      break
    }
    case "returning":
      await page.locator("#checkout-plan").waitFor()
      assert.doesNotMatch(await page.locator("#checkout-plan").innerText(), /days free|trial ends/i)
      await capture("07-plan-without-another-trial")
      break
    case "ready": {
      await page.locator("#connect-continue").waitFor()
      assert.equal(await page.locator("#connect-access").count(), 0)
      assert.equal(await page.locator("select[name=site_id]").count(), 0)
      assert.equal(await page.locator("#connect-handoff input[name=site_id]").inputValue(), siteIds[0])
      await capture("09-return-to-assistant")
      await page.setViewportSize({width: 390, height: 844})
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true)
      await capture("09-return-to-assistant-mobile")
      await page.setViewportSize({width: 1360, height: 1000})

      const expired = new URL(page.url())
      expired.searchParams.set("ref", "invalid-local-fixture")
      await page.goto(expired.href)
      await page.locator("#connect-expired").waitFor()
      await capture("10-expired-request")
      break
    }
    case "choose-site":
      await page.locator("select[name=site_id]").waitFor()
      await capture("05-choose-existing-site")
      await page.locator("select[name=site_id]").selectOption(siteIds[1])
      await page.locator("#connect-select-site button").click()
      await page.locator("#connect-selected-site").waitFor()
      await page.reload()
      assert.equal(await page.locator("#connect-handoff input[name=site_id]").inputValue(), siteIds[1])
      // Selecting a site is not authorization; never submit the WorkOS handoff.
      break
    default:
      throw new Error(`Unknown local onboarding case: ${scenario}`)
  }

  assert.deepEqual(errors, [])
  console.log(`Hosted onboarding state passed: ${scenario}`)
} finally {
  try {
    if (context) await context.close()
    if (video && directory) await video.saveAs(path.join(directory, "plan-confirmation-demo.webm"))
  } finally {
    await browser.close()
    clearTimeout(deadline)
  }
}
