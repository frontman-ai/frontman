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

    const body = await res.text();
    const dataLine = body.split("\n").find((l) => l.startsWith("data: "));
    expect(dataLine).toBeDefined();
    const envelope = JSON.parse(dataLine!.slice(6));
    const routes = JSON.parse(envelope.content[0].text);

    for (const route of routes) {
      expect(route).toHaveProperty("origin");
      expect(route).toHaveProperty("isPrerendered");
      expect(route).toHaveProperty("type");
      expect(route).toHaveProperty("params");
    }

    const indexRoute = routes.find((r: { path: string }) => r.path === "/");
    expect(indexRoute).toBeDefined();
    expect(indexRoute.origin).toBe("project");
    expect(indexRoute.type).toBe("page");
    expect(indexRoute.file).toContain("index.astro");
  });

  it("should sync the preview URL after client-side navigation", async () => {
    page = await context.newPage();
    await openFrontmanUI(page, PORT);

    const preview = page.frameLocator(`iframe[title^="Preview -"][src="http://localhost:${PORT}/"]`);
    await preview.getByRole("link", { name: "About" }).click();

    await page.waitForFunction(
      (expectedUrl) =>
        document.querySelector<HTMLInputElement>('input[type="text"]')?.value === expectedUrl,
      `http://localhost:${PORT}/about/`,
    );
    await page.waitForURL(`http://localhost:${PORT}/about/frontman/`);
    await page.close();
  });

  it("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    await openFrontmanUI(page, PORT);

    await sendPrompt(page, 'Change the h1 heading text in src/pages/index.astro to say "Hello Frontman"');

    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
