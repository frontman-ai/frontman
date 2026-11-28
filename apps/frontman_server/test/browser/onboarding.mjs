import assert from "node:assert/strict"
import {createHmac} from "node:crypto"
import {chromium} from "playwright"
import {signInFixture} from "./fixture-auth.mjs"

const base = new URL(process.argv[2])
assert(["localhost", "127.0.0.1"].includes(base.hostname), "Use a local test server")
const scenario = process.env.ONBOARDING_CASE
const siteIds = JSON.parse(process.env.ONBOARDING_SITE_IDS || "[]")
const deadline = setTimeout(() => {
  console.error("Onboarding browser scenario exceeded 60 seconds")
  process.exit(1)
}, 60000)

const browser = await chromium.launch()
try {
  const context = await browser.newContext({
    viewport: {width: 1360, height: 1000},
  })
  const page = await context.newPage()
  const errors = []
  page.on("pageerror", error => errors.push(error.message))

  await page.goto(new URL("/auth/mcp/workos?external_auth_id=local-onboarding-fixture", base).href)
  await page.locator("#google-login-form").waitFor()

  await signInFixture(page, base, process.env.ONBOARDING_TEST_EMAIL, process.env.ONBOARDING_TEST_PASSWORD)
  await page.waitForURL("**/auth/mcp/workos/pending?*")
  await page.locator("#hosted-setup").waitFor()

  switch (scenario) {
    case "new-site": {
      await page.locator("#connect-no-sites").waitFor()
      assert.equal(await page.locator("#connect-continue").count(), 0)
      assert.equal(await page.locator("#connect-site-launch input[type=url]").count(), 1)
      await context.route("https://localhost/**", route => route.abort())
      for (const prefix of ["", "/blog"]) {
        for (const path of ["", "/", "/index.php", "/index.php/frontman/", "/frontman", "/wp-admin/", "/wp-admin/admin.php"]) {
          for (const [action, target] of [
            ["open", "/wp-admin/admin.php?page=frontman&frontman_intent=assistant"],
            ["install", "/wp-admin/plugin-install.php?tab=plugin-information&plugin=frontman-agentic-ai-editor"],
          ]) {
            await page.locator("#connect-site-launch input[type=url]").fill(`https://localhost${prefix}${path}`)
            const [request, popup] = await Promise.all([
              context.waitForEvent("request", request => request.url().startsWith("https://localhost/")),
              context.waitForEvent("page"),
              page.locator(`#connect-site-launch button[value=${action}]`).click(),
            ])
            assert.equal(request.isNavigationRequest(), true)
            assert.equal(request.url(), `https://localhost${prefix}${target}`)
            assert.notEqual(popup, page)
            await popup.close()
          }
        }
      }
      await context.unroute("https://localhost/**")
      break
    }
    case "trial-offer": {
      await page.locator("#connect-select-site").waitFor()
      assert.equal(await page.locator("#connect-continue").count(), 0)

      const returned = new URL(page.url())
      returned.searchParams.set("checkout", "success")
      await page.goto(returned.href)
      await page.locator("#connect-select-site select").selectOption(siteIds[0])
      await page.locator("#connect-select-site button").click()
      await page.locator("#checkout-pending").waitFor()
      assert.equal(new URL(page.url()).searchParams.get("checkout"), "success")
      assert.equal(await page.locator("#connect-continue").count(), 0)
      assert.equal(await page.locator("#checkout-plan").count(), 0)

      await page.locator("#hosted-setup > details > summary").click()
      await page.locator("#connect-change-site select").selectOption(siteIds[1])
      await page.locator("#connect-change-site button").click()
      await page.locator("#checkout-pending").waitFor()
      assert.equal(new URL(page.url()).searchParams.get("checkout"), "success")
      assert.equal(await page.locator("#connect-change-site select").inputValue(), siteIds[1])
      assert.equal(await page.locator("#checkout-plan").count(), 0)
      assert.equal(await page.locator("#connect-continue").count(), 0)

      await page.locator("#hosted-setup > details > summary").click()
      await page.getByRole("link", {name: "Refresh setup status"}).click()
      await page.locator("#checkout-pending").waitFor()
      assert.equal(new URL(page.url()).searchParams.get("checkout"), "success")
      assert.equal(await page.locator("#checkout-plan").count(), 0)
      assert.equal(await page.locator("#connect-continue").count(), 0)

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
      break
    }
    case "returning":
      await page.locator("#checkout-plan").waitFor()
      assert.doesNotMatch(await page.locator("#checkout-plan").innerText(), /days free|trial ends/i)
      break
    case "ready": {
      await page.locator("#connect-continue").waitFor()
      assert.equal(await page.locator("#connect-access").count(), 0)
      assert.equal(await page.locator("select[name=site_id]").count(), 0)
      assert.equal(await page.locator("#connect-handoff input[name=site_id]").inputValue(), siteIds[0])

      const expired = new URL(page.url())
      expired.searchParams.set("ref", "invalid-local-fixture")
      await page.goto(expired.href)
      await page.locator("#connect-expired").waitFor()
      break
    }
    case "choose-site":
      await page.locator("select[name=site_id]").waitFor()
      await page.locator("select[name=site_id]").selectOption(siteIds[1])
      await page.locator("#connect-select-site button").click()
      await page.locator("#connect-selected-site").waitFor()
      await page.reload()
      assert.equal(await page.locator("#connect-handoff input[name=site_id]").inputValue(), siteIds[1])
      break
    default:
      throw new Error(`Unknown local onboarding case: ${scenario}`)
  }

  assert.deepEqual(errors, [])
  console.log(`Hosted onboarding state passed: ${scenario}`)
} finally {
  clearTimeout(deadline)
  await browser.close()
}
