import {
	type Browser,
	type BrowserContext,
	chromium,
	type Page,
} from "playwright";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
	type FrameworkServer,
	headingFileContains,
	startNextjs,
	stopFramework,
} from "../helpers/framework.js";
import {
	openFrontmanUI,
	proveRecoveryAfterFrameworkMcpFailure,
} from "../helpers/frontman-ui.js";
import { installNextjs } from "../helpers/installer.js";
import { MCP_ORIGIN, MCP_TOKEN } from "../helpers/mcp.js";

const PORT = 3010;

describe("Next.js E2E", () => {
	let browser: Browser;
	let context: BrowserContext;
	let page: Page;
	let server: FrameworkServer;

	beforeAll(async () => {
		installNextjs();

		browser = await chromium.launch({ headless: true });
		context = await browser.newContext({ ignoreHTTPSErrors: true });
		server = await startNextjs(PORT, {
			...process.env,
			FRONTMAN_MCP_ALLOWED_ORIGINS: `${MCP_ORIGIN},http://localhost:${PORT}`,
			FRONTMAN_MCP_TOKEN: MCP_TOKEN,
		});
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
		await openFrontmanUI(selectorPage, PORT, {
			assertHealthy: server.assertHealthy,
		});

		const agentSelector = selectorPage.getByRole("combobox", { name: "Agent" });
		const modelSelector = selectorPage.getByRole("combobox", { name: "Model" });
		await agentSelector.waitFor();
		await modelSelector.waitFor();
		expect(await agentSelector.textContent()).toContain("Executor");

		await agentSelector.focus();
		await agentSelector.press("ArrowDown");
		await agentSelector.press("Home");
		await agentSelector.press("Enter");
		expect(await agentSelector.textContent()).toContain("Executor");

		await selectorPage.reload();
		await agentSelector.waitFor();
		expect(await agentSelector.textContent()).toContain("Executor");

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
			const modelBox = await modelSelector.boundingBox();
			const promptBox = await selectorPage
				.getByRole("textbox", { name: "What would you like to change?" })
				.boundingBox();
			const attachBox = await selectorPage
				.getByTitle("Attach files (images or PDFs up to 10MB)")
				.boundingBox();
			expect(panelBox).not.toBeNull();
			expect(selectorBox).not.toBeNull();
			expect(modelBox).not.toBeNull();
			expect(promptBox).not.toBeNull();
			expect(attachBox).not.toBeNull();
			expect(selectorBox!.x).toBeGreaterThanOrEqual(panelBox!.x);
			expect(selectorBox!.x + selectorBox!.width).toBeLessThanOrEqual(
				panelBox!.x + panelBox!.width,
			);
			expect(modelBox!.x).toBeGreaterThanOrEqual(panelBox!.x);
			expect(modelBox!.x + modelBox!.width).toBeLessThanOrEqual(
				panelBox!.x + panelBox!.width,
			);
			expect(Math.abs(modelBox!.y - selectorBox!.y)).toBeLessThanOrEqual(1);
			expect(promptBox!.y + promptBox!.height).toBeLessThanOrEqual(
				selectorBox!.y,
			);
			expect(promptBox!.y + promptBox!.height).toBeLessThanOrEqual(modelBox!.y);
			expect(attachBox!.y + attachBox!.height).toBeLessThanOrEqual(
				promptBox!.y,
			);
		}

		await selectorPage.close();
	});

	it("keeps browser operations usable after MCP failure and ACP reconnect", async () => {
		page = await context.newPage();

		const marker = await proveRecoveryAfterFrameworkMcpFailure(
			page,
			context,
			PORT,
			"pages/index.tsx",
			{ assertHealthy: server.assertHealthy },
		);

		expect(headingFileContains(server, marker)).toBe(true);
	});
});
