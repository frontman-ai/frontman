import {
  type Browser,
  type BrowserContext,
  chromium,
  type Page,
} from "playwright";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { submitSignIn } from "../helpers/auth.js";

const PHOENIX_ORIGIN = "https://localhost:4002";

describe("OAuth start E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;

  beforeAll(async () => {
    browser = await chromium.launch({ headless: true });
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    page = await context.newPage();
  });

  afterAll(async () => {
    await page?.close().catch(() => {});
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
  });

  it.each([
    { provider: "google", workosProvider: "GoogleOAuth", label: "Continue with Google" },
    { provider: "github", workosProvider: "GitHubOAuth", label: "Continue with GitHub" },
  ])("redirects $provider sign-in to WorkOS", async ({ provider, workosProvider, label }) => {
    await page.goto(`${PHOENIX_ORIGIN}/users/log-in?framework=nextjs`);

    expect(await page.locator('#login-form, #email-link-form, input[type="password"]').count()).toBe(0);
    const form = page.locator(`#${provider}-login-form`);
    expect(await form.getAttribute("method")).toBe("post");
    expect(await form.getAttribute("action")).toBe(`/auth/${provider}`);
    expect(await form.getByRole("button", { name: label, exact: true }).isVisible()).toBe(true);
    const csrf = await form.locator('input[name="_csrf_token"]').inputValue();
    expect(csrf).not.toBe("");
    const denied = await page.request.post(`${PHOENIX_ORIGIN}/auth/${provider}`, {
      form: {},
      maxRedirects: 0,
    });
    expect(denied.status()).toBe(403);
    const states = new Set<string>();
    for (let attempt = 0; attempt < 2; attempt++) {
      const response = await page.request.post(`${PHOENIX_ORIGIN}/auth/${provider}`, {
        form: { _csrf_token: csrf },
        maxRedirects: 0,
      });
      expect(response.status()).toBe(302);
      const location = new URL(response.headers()["location"]);
      expect(location.origin).toBe("https://api.workos.com");
      expect(location.pathname).toBe("/user_management/authorize");
      expect(location.searchParams.get("provider")).toBe(workosProvider);
      expect(location.searchParams.get("redirect_uri")).toBe(`${PHOENIX_ORIGIN}/auth/callback`);
      const state = location.searchParams.get("state");
      expect(state).toMatch(/^[A-Za-z0-9_-]{22}$/);
      states.add(state!);
    }
    expect(states.size).toBe(2);
  });

  it("completes backend email authorization when the original popup resumes after sign-in in another tab", async () => {
    const emailContext = await browser.newContext({ ignoreHTTPSErrors: true });
    try {
      const assets = await emailContext.request.get(`${PHOENIX_ORIGIN}/assets/js/app.js`);
      expect(assets.ok()).toBe(true);
      expect(assets.headers()["content-type"]).toContain("javascript");
      const client = await emailContext.newPage();
      await client.goto("http://localhost:5173/");
      await client.addScriptTag({
        type: "module",
        url: "http://localhost:5173/test/browser/Client__EmbeddedEmailBrowserFixture.res.mjs",
      });

      const before = await emailContext.request.get(`${PHOENIX_ORIGIN}/dev/mailbox/json`);
      expect(before.ok()).toBe(true);
      const previous = new Set<string>(
        (await before.json()).data.map((email: { headers: Record<string, string> }) =>
          email.headers["Message-ID"],
        ),
      );

      const popupPromise = client.waitForEvent("popup");
      await client.locator("#start-email-authorization").click();
      const popup = await popupPromise;
      await popup.waitForLoadState("domcontentloaded");
      const authorizationUrl = new URL(popup.url());
      const state = authorizationUrl.searchParams.get("embedded_state");
      expect(state).toBeTruthy();
      await popup.goto(await submitSignIn(popup, { email: "e2e@frontman.local" }));
      expect(new URL(popup.url()).searchParams.get("embedded_state")).toBe(state);
      expect(new URL(popup.url()).searchParams.get("embedded_origin")).toBe(
        authorizationUrl.searchParams.get("embedded_origin"),
      );

      const mailbox = await emailContext.request.get(`${PHOENIX_ORIGIN}/dev/mailbox/json`);
      expect(mailbox.ok()).toBe(true);
      const emails: Array<{
        to: string[];
        headers: Record<string, string>;
        text_body: string;
      }> = (await mailbox.json()).data;
      const email = emails.find((candidate) =>
        candidate.to.some((recipient) => recipient.includes("e2e@frontman.local")) &&
        !previous.has(candidate.headers["Message-ID"]),
      );
      expect(email).toBeDefined();
      const emailUrl = email!.text_body.match(/https?:\/\/\S+\/users\/log-in\/\S+/)?.[0];
      expect(emailUrl).toBeTruthy();
      expect(new URL(emailUrl!).search).toBe("");

      const emailTab = await emailContext.newPage();
      expect(await emailTab.opener()).toBeNull();
      await emailTab.goto(emailUrl!);
      await emailTab.getByRole("button", { name: "Log me in only this time", exact: true }).click();
      expect(await emailTab.locator("#embedded-client-auth-completion").count()).toBe(0);
      expect(await client.locator("#start-email-authorization").getAttribute("title")).toBe("pending");
      expect(await client.evaluate(() => localStorage.getItem("frontman:embeddedClientToken"))).toBeNull();

      await popup.goto(authorizationUrl.toString());
      expect(await popup.opener()).toBe(client);
      expect(new URL(popup.url()).searchParams.get("embedded_state")).toBe(state);
      await popup.locator('#embedded-connect-form button[type="submit"]').click();
      await popup.locator("#embedded-client-auth-completion").waitFor({ state: "attached" });
      await client.waitForFunction(
        () => document.getElementById("start-email-authorization")?.getAttribute("title") === "complete",
        undefined,
        { timeout: 10_000 },
      );
      expect(await client.evaluate(() => Boolean(localStorage.getItem("frontman:embeddedClientToken")))).toBe(true);
    } finally {
      await emailContext.close();
    }
  });
});
