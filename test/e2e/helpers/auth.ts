
import type { Page } from "playwright";

const E2E_EMAIL = "e2e@frontman.local";
const E2E_PASSWORD = "e2epassword123!";

const PHOENIX_ORIGIN = "https://localhost:4002";

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

export async function ensureLoggedIn(page: Page): Promise<void> {
  await page.goto(`${PHOENIX_ORIGIN}/users/settings`);
  const url = page.url();

  if (url.includes("/users/log-in")) {
    await login(page);
  }
}
