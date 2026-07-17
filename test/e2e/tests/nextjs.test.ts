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

  it("should render pages without breaking", async () => {
    const res = await fetch(`http://127.0.0.1:${PORT}/`);
    const html = await res.text();
    expect(res.status).toBe(200);
    expect(html).toContain("Hello World");
  });

  it("selects agents accessibly without overflowing chat widths", async () => {
    const selectorPage = await context.newPage();
    await openFrontmanUI(selectorPage, PORT, { assertHealthy: server.assertHealthy });

    const agentSelector = selectorPage.getByRole("combobox", { name: "Agent" });
    await agentSelector.waitFor();
    expect(await agentSelector.textContent()).toContain("Planner");

    await agentSelector.focus();
    await agentSelector.press("ArrowDown");
    await agentSelector.press("Home");
    await agentSelector.press("Enter");
    expect(await agentSelector.textContent()).toContain("Executor");

    await selectorPage.reload();
    await agentSelector.waitFor();
    expect(await agentSelector.textContent()).toContain("Planner");

    for (const width of [280, 384, 600]) {
      await selectorPage.evaluate((chatboxWidth) => {
        localStorage.setItem("frontman:chatbox-width", String(chatboxWidth));
      }, width);
      await selectorPage.reload();

      await agentSelector.waitFor();
      const panel = agentSelector.locator(
        `xpath=ancestor::*[contains(@style, "width: ${width}px")][1]`,
      );
      const panelBox = await panel.boundingBox();
      const selectorBox = await agentSelector.boundingBox();
      const promptBox = await selectorPage.getByRole("textbox").boundingBox();
      const attachBox = await selectorPage
        .getByTitle("Attach files (images or PDFs up to 10MB)")
        .boundingBox();
      expect(panelBox).not.toBeNull();
      expect(selectorBox).not.toBeNull();
      expect(promptBox).not.toBeNull();
      expect(attachBox).not.toBeNull();
      expect(selectorBox!.x).toBeGreaterThanOrEqual(panelBox!.x);
      expect(selectorBox!.x + selectorBox!.width).toBeLessThanOrEqual(
        panelBox!.x + panelBox!.width,
      );
      expect(selectorBox!.y + selectorBox!.height).toBeLessThanOrEqual(promptBox!.y);
      expect(selectorBox!.y + selectorBox!.height).toBeLessThanOrEqual(attachBox!.y);
    }

    await selectorPage.close();
  });

  it("should make a text change via AI prompt", async () => {
    page = await context.newPage();

    // Navigate to the Frontman UI (handles login redirect)
    await openFrontmanUI(page, PORT, { assertHealthy: server.assertHealthy });

    // Send a prompt to change the heading text
    await sendPrompt(page, 'Change the h1 heading text in pages/index.tsx to say "Hello Frontman"');

    // Verify the source file was actually modified
    expect(headingFileContains(server, "Hello Frontman")).toBe(true);
  });
});
