import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { startVueVite, stopFramework, headingFileContains, type FrameworkServer } from "../helpers/framework.js";
import { openFrontmanUI, sendPrompt } from "../helpers/frontman-ui.js";
import { installVueVite } from "../helpers/installer.js";

const PORT = 3013;
const providerIt = it.skipIf(
  !process.env.E2E_OPENAI_ACCESS_TOKEN || !process.env.E2E_OPENAI_REFRESH_TOKEN,
);

describe("Vue + Vite E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;
  let server: FrameworkServer;

  beforeAll(async () => {
    installVueVite();

    browser = await chromium.launch({ headless: true });
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    server = await startVueVite(PORT);
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

  providerIt("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    await openFrontmanUI(page, PORT);

    await sendPrompt(page, 'Change the h1 heading text in src/App.vue to say "Hello Frontman"');

    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
