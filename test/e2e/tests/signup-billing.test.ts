import { randomUUID } from "node:crypto";
import { chromium, type Browser, type Page } from "playwright";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as S from "sury";
import { installVite, resetFixture } from "../helpers/installer.js";
import { resolve } from "node:path";
import { startVite, stopFramework, type FrameworkServer } from "../helpers/framework.js";
import { cleanupSignup, providerRequest, requiredEnv } from "../helpers/real-services.js";

const PHOENIX = "https://localhost:4002";
const PORT = 3012;
const billingSchema = S.schema({ status: S.string, access_allowed: S.boolean, trial_eligible: S.boolean });

describe("Real SSO signup and Stripe billing", () => {
  const email = `frontman-e2e-${randomUUID()}@example.com`;
  const sessions: string[] = [];
  let browser: Browser | undefined;
  let server: FrameworkServer | undefined;

  beforeAll(async () => {
    expect(requiredEnv("E2E_SIGNUP_BILLING")).toBe("true");
    installVite();
    browser = await chromium.launch({ headless: true });
    server = await startVite(PORT);
  });

  afterAll(async () => {
    const results = await Promise.allSettled([
      cleanupSignup(email, sessions), browser?.close(),
      stopFramework(server).finally(() => resetFixture(resolve(import.meta.dirname, "../fixtures/vite"))),
    ]);
    const errors = results.filter(result => result.status === "rejected").map(result => result.reason);
    if (errors.length) throw new AggregateError(errors, "Signup E2E cleanup failed");
  });

  it("creates a user through SSO, denies canceled checkout, and activates from Stripe webhooks", { retry: 0, timeout: 300_000 }, async () => {
    const users = await providerRequest("workos", `user_management/users?email=${encodeURIComponent(email)}`,
      S.schema({ data: S.array(S.schema({ id: S.string })) }));
    expect(users.data).toHaveLength(0);
    const context = await browser!.newContext({ ignoreHTTPSErrors: true });
    context.setDefaultTimeout(30_000);
    const page = await context.newPage();
    await page.goto(`http://localhost:${PORT}/frontman`);
    const popupPromise = page.waitForEvent("popup");
    await page.getByRole("link", { name: "Sign in", exact: true }).click();
    const popup = await popupPromise;
    await popup.getByRole("link", { name: "Sign in with test SSO" }).click();
    await popup.getByLabel(/^email( address)?$/i).fill(email);
    await popup.getByLabel(/first name/i).fill("Frontman");
    await popup.getByLabel(/last name/i).fill("E2E");
    await popup.getByRole("button", { name: /sign in|continue|log in/i }).click();
    await popup.waitForURL(`${PHOENIX}/users/popup-complete`);
    await popup.getByRole("button", { name: "Allow and continue" }).click();
    await page.locator('div[role="textbox"]').waitFor();
    const token = await page.evaluate(() => localStorage.getItem("frontman:embeddedClientToken"));
    expect(token).toBeTruthy();
    const headers = { Authorization: `Bearer ${token}` };
    const status = async () => {
      const response = await context.request.get(`${PHOENIX}/api/billing/status`, { headers });
      expect(response.status()).toBe(200);
      return S.parser(billingSchema)(await response.json());
    };
    const me = await context.request.get(`${PHOENIX}/api/user/me`, { headers });
    expect(me.status()).toBe(200);
    const user = S.parser(S.schema({ id: S.string, email: S.string }))(await me.json());
    expect(user.email).toBe(email);
    expect(await status()).toMatchObject({ status: "none", access_allowed: false, trial_eligible: true });
    await page.getByRole("button", { name: "Choose Monthly", exact: true }).waitFor();

    const openCheckout = async (): Promise<Page> => {
      const checkoutResponse = page.waitForResponse(response => response.url() === `${PHOENIX}/api/billing/checkout` && response.request().method() === "POST");
      const tabPromise = context.waitForEvent("page");
      await page.getByRole("button", { name: "Choose Monthly", exact: true }).click();
      const response = await checkoutResponse;
      expect(response.status()).toBe(200);
      const { url } = S.parser(S.schema({ url: S.string }))(await response.json());
      const sessionId = url.match(/cs_test_[A-Za-z0-9]+/)?.[0];
      expect(sessionId).toBeDefined();
      sessions.push(sessionId!);
      const checkout = await tabPromise;
      await checkout.waitForURL(/https:\/\/checkout\.stripe\.com\//);
      return checkout;
    };

    const canceled = await openCheckout();
    const canceledSession = await providerRequest("stripe", `checkout/sessions/${sessions[0]}`,
      S.schema({ livemode: false, cancel_url: S.string, client_reference_id: S.string }));
    expect(canceledSession.client_reference_id).toBe(user.id);
    await canceled.getByRole("link", { name: /back/i }).click();
    await canceled.waitForURL(canceledSession.cancel_url);
    await canceled.getByText("Close this tab to continue in Frontman.", { exact: false }).waitFor();
    await canceled.close();
    await page.getByRole("button", { name: "Canceled checkout? Choose again" }).click();
    expect((await status()).access_allowed).toBe(false);

    const checkout = await openCheckout();
    await checkout.locator("#cardNumber").fill("4242424242424242");
    await checkout.locator("#cardExpiry").fill(`12${String(new Date().getUTCFullYear() + 3).slice(-2)}`);
    await checkout.locator("#cardCvc").fill("123");
    await checkout.locator("#billingName").fill("Frontman E2E");
    await checkout.locator("#billingCountry").selectOption("US");
    for (const [id, value] of [["billingAddressLine1", "123 Main St"], ["billingLocality", "New York"]]) {
      const input = checkout.locator(`#${id}`);
      if (await input.isVisible()) await input.fill(value);
    }
    const state = checkout.locator("#billingAdministrativeArea");
    if (await state.isVisible()) await state.selectOption("NY");
    await checkout.locator("#billingPostalCode").fill("10001");
    await checkout.getByRole("button", { name: /start trial|subscribe/i }).click();
    await checkout.waitForURL(`${PHOENIX}/billing/stripe-return/success?session_id=*`, { timeout: 90_000 });
    await expect.poll(status, { timeout: 60_000 }).toMatchObject({ status: "trialing", access_allowed: true, trial_eligible: false });
    await expect.poll(() => page.getByRole("button", { name: "Choose Monthly", exact: true }).count(), { timeout: 30_000 }).toBe(0);
    await page.getByText("Trialing", { exact: true }).waitFor();
    await checkout.close();
    await context.close();
  });
});
