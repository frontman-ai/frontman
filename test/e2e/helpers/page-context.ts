import { resolve } from "node:path";
import { build } from "vite";
import type { Page } from "playwright";

declare global {
	interface Window {
		pageContext: typeof import("../fixtures/page-context.js");
	}
}

let bundle: string;
export async function openPreview(
	page: Page,
	url: string,
	basePath = "frontman",
) {
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
	await page.route("https://parent.test/**", (route) =>
		route.fulfill({
			contentType: "text/html",
			body: `<!doctype html><title>Parent shell</title><body><script>window.__frontmanRuntime={framework:"vite",basePath:${JSON.stringify(basePath)}}</script><script src="/fixture.js"></script>`,
		}),
	);
	await page.route("https://parent.test/fixture.js", (route) =>
		route.fulfill({ contentType: "text/javascript", body: bundle }),
	);
	await page.goto("https://parent.test");
	await page.evaluate((url) => window.pageContext.mount(url), url);
	await page.waitForFunction(() => window.pageContext.runtime() !== undefined);
}
