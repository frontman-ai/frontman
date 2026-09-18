import { resolve } from "node:path";
import type { Page } from "playwright";
import { build } from "vite";

declare global {
	interface Window {
		pageContext: typeof import("../fixtures/page-context.js");
	}
}

let bundle: string;
export async function openPreview(page: Page, url: string) {
	if (!bundle) {
		const result = await build({
			configFile: false,
			build: {
				lib: {
					entry: resolve(import.meta.dirname, "../fixtures/page-context.ts"),
					formats: ["iife"],
					name: "pageContext",
				},
				write: false,
				minify: false,
			},
			define: {
				"process.env.NODE_ENV": '"test"',
				__PACKAGE_VERSION__: '"test"',
			},
		});
		const output = (Array.isArray(result) ? result[0] : result).output;
		bundle = output.find(
			(chunk) => chunk.type === "chunk" && chunk.isEntry,
		)!.code;
	}
	const parentUrl = new URL("/__frontman-preview-test", url).href;
	const fixtureUrl = new URL("/__frontman-preview-fixture.js", url).href;
	await page.route(parentUrl, (route) =>
		route.fulfill({
			contentType: "text/html",
			body: `<!doctype html><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:"vite",basePath:"frontman"}</script><script src="${fixtureUrl}"></script>`,
		}),
	);
	await page.route(fixtureUrl, (route) =>
		route.fulfill({ contentType: "text/javascript", body: bundle }),
	);
	await page.goto(parentUrl);
	await page.evaluate((url) => window.pageContext.mount(url), url);
	await page.waitForFunction(() => window.pageContext.runtime() !== undefined);
}
