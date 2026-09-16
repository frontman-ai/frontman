import {
  type Browser,
  type BrowserContext,
  chromium,
  type Page,
} from "playwright";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const PHOENIX_ORIGIN = "https://localhost:4002";

describe("OAuth start E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;

  beforeAll(async () => {
    browser = await chromium.launch({ headless: true });
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    await context.route("https://api.workos.com/**", (route) => route.abort());
    page = await context.newPage();
  });

  afterAll(async () => {
    await page?.close().catch(() => {});
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
  });

  it.each([
    { provider: "google", workosProvider: "GoogleOAuth", label: "Login with Google" },
    { provider: "github", workosProvider: "GitHubOAuth", label: "Login with GitHub" },
  ])("redirects $provider sign-in to WorkOS", async ({ provider, workosProvider, label }) => {
    await page.goto(`${PHOENIX_ORIGIN}/users/log-in?framework=nextjs`);

    const responsePromise = page.waitForResponse(
      (response) =>
        response.url() === `${PHOENIX_ORIGIN}/auth/${provider}` &&
        response.status() === 302,
    );

    await page.getByRole("link", { name: label }).click();
    const response = await responsePromise;
    const location = response.headers()["location"];

    expect(location).toContain("https://api.workos.com/user_management/authorize");
    expect(location).toContain(`provider=${workosProvider}`);
    expect(location).toContain("redirect_uri=https%3A%2F%2Flocalhost%3A4002%2Fauth%2Fcallback");
  });
});
