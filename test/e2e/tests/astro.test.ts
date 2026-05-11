import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { startAstro, stopFramework, headingFileContains, type FrameworkServer } from "../helpers/framework.js";
import { openFrontmanUI, sendPrompt } from "../helpers/frontman-ui.js";
import { installAstro } from "../helpers/installer.js";

const PORT = 3011;

describe("Astro E2E", () => {
  let browser: Browser;
  let context: BrowserContext;
  let page: Page;
  let server: FrameworkServer;

  beforeAll(async () => {
    // Configure Frontman integration in astro.config.mjs
    installAstro();

    browser = await chromium.launch({ headless: true });
    context = await browser.newContext({ ignoreHTTPSErrors: true });
    server = await startAstro(PORT);
  });

  afterAll(async () => {
    await page?.close().catch(() => {});
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
    await stopFramework(server);
  });

  it("should render pages without breaking", async () => {
    const res = await fetch(`http://127.0.0.1:${PORT}/`);
    const html = await res.text();
    expect(res.status).toBe(200);
    expect(html).toContain("Hello World");
  });

  it("should return resolved routes from get_client_pages", async () => {
    const res = await fetch(`http://127.0.0.1:${PORT}/frontman/tools/call/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "get_client_pages", arguments: {} }),
    });
    expect(res.status).toBe(200);

    // Parse SSE response to extract the tool result
    const body = await res.text();
    const dataLine = body.split("\n").find((l) => l.startsWith("data: "));
    expect(dataLine).toBeDefined();
    const envelope = JSON.parse(dataLine!.slice(6));
    const routes = JSON.parse(envelope.content[0].text);

    // Verify v5 resolved route fields are present on each route
    for (const route of routes) {
      expect(route).toHaveProperty("origin");
      expect(route).toHaveProperty("isPrerendered");
      expect(route).toHaveProperty("type");
      expect(route).toHaveProperty("params");
    }

    // The fixture's index.astro should appear as a project page
    const indexRoute = routes.find((r: { path: string }) => r.path === "/");
    expect(indexRoute).toBeDefined();
    expect(indexRoute.origin).toBe("project");
    expect(indexRoute.type).toBe("page");
    expect(indexRoute.file).toContain("index.astro");
  });

  it("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    // Navigate to the Frontman UI (handles login redirect)
    await openFrontmanUI(page, PORT);

    // Send a prompt to change the heading text
    await sendPrompt(page, 'Change the h1 heading text in src/pages/index.astro to say "Hello Frontman"');

    // Verify the source file was actually modified
    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
