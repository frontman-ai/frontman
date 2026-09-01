/**
 * Playwright helpers for interacting with the Frontman chat UI.
 *
 * The Frontman UI is a React app mounted directly into <div id="root">.
 * Key selectors:
 *   - Message input: div[role="textbox"] (contentEditable)
 *   - Send button: button[type="submit"]
 *   - Stop button: button[title="Stop generation"]
 */

import { randomUUID } from "node:crypto";
import type { BrowserContext, Page, Response, Route, WebSocketRoute } from "playwright";

interface OpenFrontmanUIOptions {
  assertHealthy?: () => void;
}

/** Elapsed time since a reference timestamp, formatted as "Xs". */
function elapsed(since: number): string {
  return `${((Date.now() - since) / 1000).toFixed(1)}s`;
}

async function assertFrontmanRoute(page: Page, response: Response | null, frontmanUrl: string): Promise<void> {
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

async function waitForTextbox(page: Page, options: OpenFrontmanUIOptions): Promise<void> {
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

  const response = await page.goto(frontmanUrl, {
    waitUntil: "domcontentloaded",
  });
  options.assertHealthy?.();
  console.log(`  [e2e] Navigated to frontman (${elapsed(t0)}), URL: ${page.url()}`);
  console.log(`  [e2e] Page title: ${await page.title()}`);
  await assertFrontmanRoute(page, response, frontmanUrl);

  await page.waitForLoadState("load", { timeout: 30_000 });
  console.log(`  [e2e] Page load event fired (${elapsed(t0)}), URL: ${page.url()}`);

  const html = await page.content();
  console.log(`  [e2e] Page HTML (first 500): ${html.substring(0, 500)}`);

  const rootChildren = await page
    .locator("#root")
    .innerHTML()
    .catch(() => "NOT_FOUND");
  console.log(`  [e2e] #root innerHTML (first 300): ${rootChildren.substring(0, 300)}`);

  const welcomeModal = page.locator("text=Welcome to Frontman!");
  const hasWelcome = await welcomeModal.isVisible().catch(() => false);
  if (hasWelcome) {
    console.log("  [e2e] Welcome modal detected — clicking sign in");
    const signInBtn = page.locator("button", { hasText: "Sign in now" });
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
export async function sendPrompt(page: Page, prompt: string): Promise<void> {
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

export async function proveRecoveryAfterFrameworkMcpFailure(
  page: Page,
  context: BrowserContext,
  devServerPort: number,
  sourceFile: string,
  options: OpenFrontmanUIOptions = {},
): Promise<string> {
  const endpoint = `http://localhost:${devServerPort}/mcp`;
  let failedDiscovery = 0;
  let resolveFailedDiscovery!: () => void;
  const failedDiscoveryPromise = new Promise<void>((resolve) => {
    resolveFailedDiscovery = resolve;
  });
  const failMcp = async (route: Route) => {
    const request = route.request();
    if (request.url() === endpoint && request.method() === "POST") {
      failedDiscovery += 1;
      resolveFailedDiscovery();
      await route.fulfill({ status: 503, body: "" });
    } else {
      await route.continue();
    }
  };
  let currentPhoenixSocket: WebSocketRoute | undefined;
  let resolveReconnectedSocket: ((socket: WebSocketRoute) => void) | undefined;
  const consentPrompts: string[] = [];
  await page.exposeFunction("__frontmanRecordConsent", (message: string) => {
    consentPrompts.push(message);
  });
  await page.addInitScript(() => {
    const testWindow = window as typeof window & {
      __frontmanRecordConsent: (message: string) => Promise<void>;
    };
    window.confirm = (message) => {
      testWindow.__frontmanRecordConsent(String(message));
      return true;
    };
  });
  await page.routeWebSocket("**/socket/websocket**", (socket) => {
    socket.connectToServer();
    currentPhoenixSocket = socket;
    resolveReconnectedSocket?.(socket);
    resolveReconnectedSocket = undefined;
  });
  await page.route("**/mcp", failMcp);
  try {
    await openFrontmanUI(page, devServerPort, options);
    await Promise.race([
      failedDiscoveryPromise,
      page.waitForTimeout(30_000).then(() => {
        throw new Error(`[e2e] Framework MCP discovery did not reach ${endpoint}`);
      }),
    ]);
    if (failedDiscovery === 0) {
      throw new Error(`[e2e] Framework MCP discovery did not reach ${endpoint}`);
    }
    await page.unroute("**/mcp", failMcp);
    const successfulDiscovery = page.waitForResponse(
      (response) => response.url() === endpoint
        && response.request().method() === "POST"
        && response.status() === 200,
      { timeout: 30_000 },
    );
    await page.reload({ waitUntil: "domcontentloaded" });
    await successfulDiscovery;
    await page.waitForTimeout(500);
    if (!currentPhoenixSocket) {
      throw new Error("[e2e] Initial ACP Phoenix WebSocket did not connect");
    }
    const reconnectedSocket = new Promise<WebSocketRoute>((resolve) => {
      resolveReconnectedSocket = resolve;
    });
    currentPhoenixSocket.close();
    await reconnectedSocket;
    await page.locator('div[role="textbox"][contenteditable="true"]').waitFor({ state: "visible", timeout: 60_000 });

    const marker = `frontman-recovery-${randomUUID()}`;
    const previewBody = page
      .frameLocator('iframe[title^="Preview -"]:not([src="about:blank"])')
      .first()
      .locator("body");
    await previewBody.waitFor({ state: "visible", timeout: 30_000 });
    await previewBody.evaluate((body, value) => {
      body.dataset.frontmanE2eProof = value;
    }, marker);

    await sendPrompt(
      page,
      `Perform these steps in order and do not stop until all are complete: (1) call execute_js with the expression document.body.dataset.frontmanE2eProof to read the marker from the preview; (2) call read_file for ${sourceFile}; (3) call edit_file to replace the h1 heading text in ${sourceFile} with that exact marker; (4) report the marker. You must call all three named tools.`,
    );
    if (!consentPrompts.some((prompt) => prompt.includes("read-only tools"))) {
      throw new Error("[e2e] Read-only tool session consent was not requested");
    }
    if (!consentPrompts.some((prompt) => prompt.includes("write tool"))) {
      throw new Error("[e2e] Write-tool consent was not requested");
    }
    return marker;
  } finally {
    await context.setOffline(false).catch(() => {});
    await page.unroute("**/mcp", failMcp).catch(() => {});
  }
}
