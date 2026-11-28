import { randomUUID } from "node:crypto";
import type { Page } from "playwright";

const E2E_EMAIL = "e2e@frontman.local";
const E2E_PASSWORD = "e2epassword123!";

const PHOENIX_ORIGIN = "https://localhost:4002";
const EMBEDDED_TOKEN_STORAGE_KEY = "frontman:embeddedClientToken";

export async function login(
  page: Page,
  opts?: { returnTo?: string },
): Promise<void> {
  const maxAttempts = 2;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await loginOnce(page, opts);
      return;
    } catch {
      if (attempt < maxAttempts) {
        console.log(`  [e2e] Login attempt ${attempt} failed, retrying…`);
      } else {
        throw new Error("[e2e] Login failed after two attempts");
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

  await login(page);
  await page.goto(loginUrl.toString());

  await page.locator('#embedded-connect-form button[type="submit"]').click();
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
    console.log("  [e2e] Already authenticated — skipped login form");
    return;
  }

  await loginSeededAccount(page, E2E_EMAIL, E2E_PASSWORD);

  await page.waitForURL((url) => !url.pathname.includes("/users/log-in"), {
    timeout: 30_000,
  });
}

export async function submitSignIn(
  page: Page,
  user: { email: string; password?: string },
): Promise<string> {
  const csrf = await page.locator('meta[name="csrf-token"]').getAttribute("content");
  if (!csrf) throw new Error("Sign-in page has no CSRF token");
  const form: Record<string, string> = {
    _csrf_token: csrf,
    "user[email]": user.email,
  };
  if (user.password !== undefined) form["user[password]"] = user.password;
  const url = new URL(page.url());
  for (const name of ["embedded_origin", "embedded_state"]) {
    const value = url.searchParams.get(name);
    if (value !== null) form[name] = value;
  }
  const response = await page.request.post(`${PHOENIX_ORIGIN}/users/log-in`, {
    form,
    maxRedirects: 0,
  });
  if (response.status() !== 302) {
    throw new Error(`Seeded sign-in request failed with HTTP ${response.status()}`);
  }
  const location = response.headers()["location"];
  if (!location) throw new Error("Sign-in response has no redirect");
  return new URL(location, PHOENIX_ORIGIN).toString();
}

export async function loginSeededAccount(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  await page.goto(await submitSignIn(page, { email, password }));
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
