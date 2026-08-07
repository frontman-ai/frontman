/**
 * Playwright helpers for interacting with the Frontman chat UI.
 *
 * The Frontman UI is a React app mounted directly into <div id="root">.
 * Key selectors:
 *   - Message input: div[role="textbox"] (contentEditable)
 *   - Send button: button[type="submit"]
 *   - Stop button: button[title="Stop generation"]
 */

import type { Page, Response } from "playwright";

const PHOENIX_ORIGIN = "https://localhost:4002";

interface OpenFrontmanUIOptions {
  assertHealthy?: () => void;
}

/** Elapsed time since a reference timestamp, formatted as "Xs". */
function elapsed(since: number): string {
  return `${((Date.now() - since) / 1000).toFixed(1)}s`;
}

async function assertFrontmanRoute(
  page: Page,
  response: Response | null,
  frontmanUrl: string,
): Promise<void> {
  const status = response?.status();
  const title = await page.title().catch(() => "");
  if (
    (status !== undefined && status >= 400) ||
    title.startsWith("404") ||
    title.includes("This page could not be found")
  ) {
    throw new Error(
      `[e2e] Frontman UI route failed: GET ${frontmanUrl} returned ${status ?? "no response"}, title=${JSON.stringify(title)}, url=${page.url()}`,
    );
  }
}

async function waitForTextbox(
  page: Page,
  options: OpenFrontmanUIOptions,
): Promise<void> {
  const timeoutMs = 60_000;
  const deadline = Date.now() + timeoutMs;
  const textbox = page.locator('div[role="textbox"]');

  while (Date.now() < deadline) {
    options.assertHealthy?.();
    if (await textbox.isVisible().catch(() => false)) return;
    await page.waitForTimeout(500);
  }

  options.assertHealthy?.();
  throw new Error(`[e2e] Frontman textbox did not become visible within ${timeoutMs}ms`);
}

/**
 * Navigate to the Frontman UI within a framework dev server.
 * Handles the authentication flow:
 *   1. Navigate to /frontman on the dev server
 *   2. The Frontman client JS loads and tries to connect via WebSocket
 *   3. If not authenticated, it redirects to the Phoenix login page
 *   4. We intercept that and log in first, then re-navigate
 *
 * NOTE: We use waitUntil:"load" / waitForLoadState("load") instead of
 * "networkidle" — HMR WebSockets and long-poll connections keep the network
 * busy indefinitely, making "networkidle" unreliable on slow CI runners.
 * The actual UI readiness check is the textbox locator at the end.
 */
export async function openFrontmanUI(
  page: Page,
  devServerPort: number,
  options: OpenFrontmanUIOptions = {},
): Promise<void> {
  const t0 = Date.now();
  const frontmanUrl = `http://localhost:${devServerPort}/frontman`;
  console.log(`  [e2e] openFrontmanUI: port=${devServerPort}`);

  page.on("console", (msg) => {
    const type = msg.type();
    if (type === "error" || type === "warning") {
      console.log(`  [e2e][browser ${type}] ${msg.text()}`);
    }
  });
  page.on("pageerror", (err) => {
    console.log(`  [e2e][page error] ${err.message}`);
  });

  const { login } = await import("./auth.js");
  await login(page, { returnTo: frontmanUrl });
  options.assertHealthy?.();
  console.log(`  [e2e] Login complete (${elapsed(t0)}), URL: ${page.url()}`);

  const response = await page.goto(frontmanUrl, { waitUntil: "domcontentloaded" });
  options.assertHealthy?.();
  console.log(`  [e2e] Navigated to frontman (${elapsed(t0)}), URL: ${page.url()}`);
  console.log(`  [e2e] Page title: ${await page.title()}`);
  await assertFrontmanRoute(page, response, frontmanUrl);

  await page.waitForLoadState("load", { timeout: 30_000 });
  console.log(`  [e2e] Page load event fired (${elapsed(t0)}), URL: ${page.url()}`);

  const html = await page.content();
  console.log(`  [e2e] Page HTML (first 500): ${html.substring(0, 500)}`);

  const rootChildren = await page.locator("#root").innerHTML().catch(() => "NOT_FOUND");
  console.log(`  [e2e] #root innerHTML (first 300): ${rootChildren.substring(0, 300)}`);

  const welcomeModal = page.locator('text=Welcome to Frontman!');
  const hasWelcome = await welcomeModal.isVisible().catch(() => false);
  if (hasWelcome) {
    console.log("  [e2e] Welcome modal detected — clicking sign in");
    const signInBtn = page.locator('button', { hasText: 'Sign in now' });
    if (await signInBtn.isVisible().catch(() => false)) {
      await signInBtn.click();
    }
    await page.waitForTimeout(5000);
    if (page.url().includes("/users/log-in")) {
      await login(page, { returnTo: frontmanUrl });
      options.assertHealthy?.();
      const welcomeResponse = await page.goto(frontmanUrl, {
        waitUntil: "load",
        timeout: 30_000,
      });
      options.assertHealthy?.();
      await assertFrontmanRoute(page, welcomeResponse, frontmanUrl);
    }
  }

  if (page.url().includes("/users/log-in")) {
    console.log(`  [e2e] Redirected to login (${elapsed(t0)}), re-authenticating`);
    await login(page, { returnTo: frontmanUrl });
    options.assertHealthy?.();
    const reauthResponse = await page.goto(frontmanUrl, {
      waitUntil: "load",
      timeout: 30_000,
    });
    options.assertHealthy?.();
    await assertFrontmanRoute(page, reauthResponse, frontmanUrl);
    console.log(`  [e2e] Re-navigated after re-auth (${elapsed(t0)}), URL: ${page.url()}`);
  }

  console.log(`  [e2e] Waiting for textbox to appear (${elapsed(t0)})…`);
  await waitForTextbox(page, options);
  console.log(`  [e2e] Textbox visible — UI ready (${elapsed(t0)})`);
}

/**
 * Send a prompt in the Frontman chat UI and wait for the AI response to complete.
 *
 * The input is a contentEditable div with role="textbox".
 * After typing, we press Enter to submit.
 * We wait for the agent to finish by watching for the stop button to appear
 * then disappear (replaced by the submit button again).
 */
export async function sendPrompt(
  page: Page,
  prompt: string,
): Promise<void> {
  const sendStart = Date.now();
  console.log(`  [e2e] sendPrompt: "${prompt.substring(0, 80)}…"`);

  const input = page.locator('div[role="textbox"]');
  await input.waitFor({ state: "visible", timeout: 30_000 });

  await input.click();
  await page.keyboard.type(prompt);

  await page.keyboard.press("Enter");
  console.log(`  [e2e] sendPrompt: submitted (${elapsed(sendStart)}), waiting for agent to start…`);

  const stopButton = page.locator('button[title="Stop generation"]');
  await stopButton.waitFor({ state: "visible", timeout: 30_000 });
  console.log(`  [e2e] sendPrompt: agent started (${elapsed(sendStart)})`);

  const submitButton = page.locator('button[type="submit"]');
  await stopButton.waitFor({ state: "detached", timeout: 180_000 });
  await submitButton.waitFor({ state: "visible", timeout: 10_000 });
  console.log(`  [e2e] sendPrompt: agent finished (${elapsed(sendStart)})`);

  await page.waitForTimeout(3000);
}
