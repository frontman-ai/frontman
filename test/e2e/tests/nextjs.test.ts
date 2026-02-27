import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { startNextjs, stopFramework, headingFileContains, type FrameworkServer } from "../helpers/framework.js";
import { openFrontmanUI, sendPrompt } from "../helpers/frontman-ui.js";
import { installNextjs } from "../helpers/installer.js";

const PORT = 3010;

describe("Next.js E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;
  let server: FrameworkServer;

  beforeAll(async () => {
    // Run the Frontman installer to generate middleware.ts + instrumentation.ts
    installNextjs();

    browser = await chromium.launch({ headless: true });
    // Accept self-signed mkcert certificates
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    server = await startNextjs(PORT);
  });

  afterAll(async () => {
    await page?.close().catch(() => {});
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
    await stopFramework(server);
  });

  it("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    // Navigate to the Frontman UI (handles login redirect)
    await openFrontmanUI(page, PORT);

    // Send a prompt to change the heading text
    await sendPrompt(page, 'Change the h1 heading text in pages/index.tsx to say "Hello Frontman"');

    // Verify the source file was actually modified
    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
