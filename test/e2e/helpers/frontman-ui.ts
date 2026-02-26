/**
 * Playwright helpers for interacting with the Frontman chat UI.
 *
 * The Frontman UI is a React app mounted directly into <div id="root">.
 * Key selectors:
 *   - Message input: div[role="textbox"] (contentEditable)
 *   - Send button: button[type="submit"]
 *   - Stop button: button[title="Stop generation"]
 */

import type { Page } from "playwright";

const PHOENIX_ORIGIN = "https://localhost:4002";

/**
 * Navigate to the Frontman UI within a framework dev server.
 * Handles the authentication flow:
 *   1. Navigate to /frontman on the dev server
 *   2. The Frontman client JS loads and tries to connect via WebSocket
 *   3. If not authenticated, it redirects to the Phoenix login page
 *   4. We intercept that and log in first, then re-navigate
 */
export async function openFrontmanUI(
  page: Page,
  devServerPort: number,
): Promise<void> {
  const frontmanUrl = `http://localhost:${devServerPort}/frontman`;

  // Collect ALL console messages and errors for debugging
  page.on("console", (msg) => {
    const type = msg.type();
    if (type === "error" || type === "warning") {
      console.log(`  [e2e][browser ${type}] ${msg.text()}`);
    }
  });
  page.on("pageerror", (err) => {
    console.log(`  [e2e][page error] ${err.message}`);
  });

  // First, log in directly on the Phoenix server so we have a session cookie
  const { login } = await import("./auth.js");
  await login(page, { returnTo: frontmanUrl });
  console.log(`  [e2e] Login complete, URL now: ${page.url()}`);

  // Now navigate to the Frontman UI — should load without auth redirect
  await page.goto(frontmanUrl, { waitUntil: "domcontentloaded" });
  console.log(`  [e2e] Navigated to frontman, URL: ${page.url()}`);
  console.log(`  [e2e] Page title: ${await page.title()}`);

  // Wait for the page to fully render (scripts loaded)
  await page.waitForLoadState("networkidle", { timeout: 30_000 });
  console.log(`  [e2e] Network idle, URL: ${page.url()}`);

  // Dump the page HTML for debugging (first 500 chars)
  const html = await page.content();
  console.log(`  [e2e] Page HTML (first 500): ${html.substring(0, 500)}`);

  // Check if the #root element has any children (React mounted)
  const rootChildren = await page.locator("#root").innerHTML().catch(() => "NOT_FOUND");
  console.log(`  [e2e] #root innerHTML (first 300): ${rootChildren.substring(0, 300)}`);

  // Check for the welcome modal (FTUE flow for first-time users)
  const welcomeModal = page.locator('text=Welcome to Frontman!');
  const hasWelcome = await welcomeModal.isVisible().catch(() => false);
  if (hasWelcome) {
    console.log("  [e2e] Welcome modal detected — clicking sign in");
    const signInBtn = page.locator('button', { hasText: 'Sign in now' });
    if (await signInBtn.isVisible().catch(() => false)) {
      await signInBtn.click();
    }
    // Wait for redirect and return
    await page.waitForTimeout(5000);
    // After redirect to login, re-login and come back
    if (page.url().includes("/users/log-in")) {
      await login(page, { returnTo: frontmanUrl });
      await page.goto(frontmanUrl, { waitUntil: "networkidle" });
    }
  }

  // If we got redirected to login, handle it
  if (page.url().includes("/users/log-in")) {
    console.log("  [e2e] Redirected to login, re-authenticating");
    await login(page, { returnTo: frontmanUrl });
    await page.goto(frontmanUrl, { waitUntil: "networkidle" });
  }

  // Wait for the Frontman UI to mount — the textbox should appear
  // when the app is fully loaded and WebSocket connected.
  await page
    .locator('div[role="textbox"]')
    .waitFor({ state: "visible", timeout: 60_000 });
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
  const input = page.locator('div[role="textbox"]');
  await input.waitFor({ state: "visible", timeout: 30_000 });

  // contentEditable divs need click + keyboard.type (fill may not work)
  await input.click();
  await page.keyboard.type(prompt);

  // Submit via Enter key
  await page.keyboard.press("Enter");

  // Wait for the agent to start — the stop button appears
  const stopButton = page.locator('button[title="Stop generation"]');
  await stopButton.waitFor({ state: "visible", timeout: 30_000 });

  // Wait for the agent to finish — stop button disappears, submit button returns.
  // Real ChatGPT calls with tool use can take 30-120 seconds.
  const submitButton = page.locator('button[type="submit"]');
  await stopButton.waitFor({ state: "detached", timeout: 180_000 });
  await submitButton.waitFor({ state: "visible", timeout: 10_000 });

  // Brief extra pause to let any final file writes complete
  await page.waitForTimeout(3000);
}
