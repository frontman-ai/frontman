import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { startVite, stopFramework, headingFileContains, type FrameworkServer } from "../helpers/framework.js";
import { openFrontmanUI, sendPrompt } from "../helpers/frontman-ui.js";
import { installVite } from "../helpers/installer.js";

const PORT = 3012;

describe("Vite E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;
  let server: FrameworkServer;

  beforeAll(async () => {
    installVite();

    browser = await chromium.launch({ headless: true });
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    server = await startVite(PORT);
  });

  afterAll(async () => {
    await page?.close().catch(() => {});
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
    await stopFramework(server);
  });

  it("should render pages without breaking", async () => {
    page = await context.newPage();
    const response = await page.goto(`http://127.0.0.1:${PORT}/`, {
      waitUntil: "domcontentloaded",
    });

    expect(response?.status()).toBe(200);
    await page
      .getByRole("heading", { name: "Hello World" })
      .waitFor({ state: "visible" });
  });

  it("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    await openFrontmanUI(page, PORT);

    await sendPrompt(page, 'Change the h1 heading text in src/App.tsx to say "Hello Frontman"');

    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
