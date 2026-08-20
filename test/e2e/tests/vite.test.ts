import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { startVite, stopFramework, headingFileContains, type FrameworkServer } from "../helpers/framework.js";
import { proveRecoveryAfterFrameworkMcpFailure } from "../helpers/frontman-ui.js";
import { configureInstalledMcpVite } from "../helpers/installer.js";
import { MCP_ORIGIN, MCP_TOKEN } from "../helpers/mcp.js";

const PORT = 3012;

describe("Vite E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;
  let server: FrameworkServer;

  beforeAll(async () => {
    configureInstalledMcpVite([MCP_ORIGIN, `http://localhost:${PORT}`], MCP_TOKEN);

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
    await page.getByRole("heading", { name: "Hello World" }).waitFor({ state: "visible" });
  });

  it("keeps browser operations usable after MCP failure and ACP reconnect", async () => {
    page = await context.newPage();

    const marker = await proveRecoveryAfterFrameworkMcpFailure(page, context, PORT, "src/App.tsx");

    expect(headingFileContains(server, marker)).toBe(true);
  });
});
