/**
 * Playwright helpers for authentication.
 *
 * Uses the dev-only email+password form on /users/log-in.
 */

import { randomUUID } from "node:crypto";
import type { Page } from "playwright";

const E2E_EMAIL = "e2e@frontman.local";
const E2E_PASSWORD = "e2epassword123!";

const PHOENIX_ORIGIN = "https://localhost:4002";
const EMBEDDED_TOKEN_STORAGE_KEY = "frontman:embeddedClientToken";

/**
 * Log in the e2e test user via the dev email/password form.
 *
 * Navigates to the Phoenix login page, fills the form, and submits.
 * After success, the server redirects back to `returnTo`.
 *
 * Retries once on failure — CI runners can be slow and the first
 * attempt sometimes times out waiting for the redirect.
 */
export async function login(
  page: Page,
  opts?: { returnTo?: string },
): Promise<void> {
  const maxAttempts = 2;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await loginOnce(page, opts);
      return;
    } catch (err) {
      if (attempt < maxAttempts) {
        console.log(
          `  [e2e] Login attempt ${attempt} failed, retrying… (${err instanceof Error ? err.message : err})`,
        );
      } else {
        throw err;
      }
    }
  }
}

export async function authorizeEmbeddedClient(
  page: Page,
  opts: { origin: string },
): Promise<string> {
  const state = randomUUID();
  const loginUrl = new URL("/users/log-in", PHOENIX_ORIGIN);
  loginUrl.searchParams.set("return_to", "/users/popup-complete");
  loginUrl.searchParams.set("embedded_state", state);
  loginUrl.searchParams.set("embedded_origin", opts.origin);

  await login(page, { returnTo: loginUrl.toString() });

  if (!page.url().includes("/users/popup-complete")) {
    await page.goto(loginUrl.toString());
  }

  await page.locator('button[type="submit"]', { hasText: "Allow and continue" }).click();
  await page.locator("#embedded-client-auth-completion").waitFor({
    state: "attached",
    timeout: 30_000,
  });

  const token = await page.locator("#embedded-client-auth-completion").getAttribute("data-token");
  if (!token) {
    throw new Error("Embedded client authorization completed without a token");
  }

  await page.addInitScript(
    ({ storageKey, tokenValue }) => {
      localStorage.setItem(storageKey, tokenValue);
    },
    { storageKey: EMBEDDED_TOKEN_STORAGE_KEY, tokenValue: token },
  );

  return token;
}

async function loginOnce(
  page: Page,
  opts?: { returnTo?: string },
): Promise<void> {
  const loginUrl = new URL("/users/log-in", PHOENIX_ORIGIN);
  if (opts?.returnTo) {
    loginUrl.searchParams.set("return_to", opts.returnTo);
  }

  await page.goto(loginUrl.toString());

  if (!page.url().includes("/users/log-in")) {
    console.log(`  [e2e] Already authenticated — skipped login form (URL: ${page.url()})`);
    return;
  }

  await page.locator("#login-form").waitFor({ state: "visible", timeout: 30_000 });
  await page.fill('#login-form input[type="email"]', E2E_EMAIL);
  await page.fill('#login-form input[type="password"]', E2E_PASSWORD);
  await page.click("#login-submit");

  await page.waitForURL((url) => !url.pathname.includes("/users/log-in"), {
    timeout: 30_000,
  });
}

/**
 * Ensure the user is authenticated by checking if we can access a protected page.
 * If not authenticated, performs login.
 */
export async function ensureLoggedIn(page: Page): Promise<void> {
  await page.goto(`${PHOENIX_ORIGIN}/users/settings`);
  const url = page.url();

  if (url.includes("/users/log-in")) {
    await login(page);
  }
}
