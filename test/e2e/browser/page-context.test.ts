import { readFileSync } from "node:fs";
import { chromium, firefox, webkit, type Browser } from "playwright";
import {
	afterAll,
	beforeAll,
	describe,
	expect,
	it,
	onTestFinished,
} from "vitest";
import { makeFrontmanPreviewLoaderBody } from "../../../libs/frontman-preview-bridge/src/preview-loader.mjs";
import { frontmanPreviewLoaderPlugin } from "../../../libs/frontman-preview-bridge/src/vite-plugin-preview-loader.mjs";
import { openPreview } from "../helpers/page-context.js";

const asset = (path: string) =>
	readFileSync(new URL(`../../../libs/${path}`, import.meta.url), "utf8");
const bridge = asset("frontman-preview-bridge/dist/bridge.js");
const childOrigin = "https://preview.test";
const markup =
	'<!doctype html><title>Cross-origin child</title><meta name="astro-view-transitions-enabled"><body><a href="/next?application=kept#section">Next</a>';
const inline = `<script>${makeFrontmanPreviewLoaderBody({ bridgeUrl: "/custom/preview-bridge.js" })}</script>`;
const scenarios = [
	["Astro", `${markup}${inline}${inline}`],
	[
		"Vite",
		frontmanPreviewLoaderPlugin({
			basePath: "custom",
		}).transformIndexHtml.handler(`${markup}</body>`, { path: "/" }),
	],
	["Next.js", `${markup}<script type="module" src="/next-loader.js"></script>`],
	[
		"WordPress",
		`${markup}<script src="/blog/wp-content/plugins/frontman/assets/preview-loader.js"></script>`,
	],
];

describe.each([
	["Chromium", chromium],
	["Firefox", firefox],
	["WebKit", webkit],
] as const)("page context: %s", (_name, engine) => {
	let browser: Browser;
	beforeAll(async () => {
		browser = await engine.launch();
	});
	afterAll(async () => {
		await browser?.close();
	});

	it.each(scenarios)(
		"%s loader: cross-site context, isolation and lifecycle",
		async (_platform, html) => {
			const page = await browser.newPage({ colorScheme: "dark" });
			onTestFinished(() => page.close());
			const context = async () => {
				await page.waitForFunction(
					() => window.pageContext.runtime() !== undefined,
				);
				return page.evaluate(() => window.pageContext.context());
			};
			const errors: Error[] = [];
			page.on("pageerror", (error) => errors.push(error));
			await page.route(`${childOrigin}/**`, (route) =>
				route.fulfill({ contentType: "text/html", body: html }),
			);
			for (const [path, body] of [
				["/custom/preview-bridge.js", bridge],
				["/next-loader.js", asset("frontman-nextjs/dist/preview-loader.js")],
				[
					"/blog/wp-content/plugins/frontman/assets/preview-loader.js",
					asset("frontman-wordpress/assets/preview-loader.js"),
				],
				[
					"/blog/wp-content/plugins/frontman/assets/bridge.js",
					asset("frontman-wordpress/assets/bridge.js"),
				],
			]) {
				await page.route(`${childOrigin}${path}`, (route) =>
					route.fulfill({ contentType: "text/javascript", body }),
				);
			}
			await openPreview(page, childOrigin, "custom");
			expect(
				await page.evaluate(() => {
					try {
						Reflect.get(
							document.querySelector("iframe")!.contentWindow!,
							"BS_PRIVATE_NESTED_SOME_NONE",
						);
						return "unblocked";
					} catch (error) {
						return (error as Error).name;
					}
				}),
			).toBe("SecurityError");
			expect(await context()).toMatchObject({
				title: "Cross-origin child",
				url: `${childOrigin}/`,
				colorScheme: "dark",
				astroClientRouting: "enabled",
			});

			expect(
				await page.evaluate(async (childOrigin) => {
					const sibling = document.createElement("iframe");
					sibling.name =
						"frontman:https://parent.test/?channel=sibling&basePath=custom";
					const loaded = new Promise((resolve) =>
						sibling.addEventListener("load", resolve, { once: true }),
					);
					sibling.src = `${childOrigin}/sibling`;
					document.body.appendChild(sibling);
					await loaded;
					const runtime = window.pageContext.Runtime.make(
						sibling,
						childOrigin,
						"sibling",
					);
					try {
						await window.pageContext.Runtime.whenOpen(runtime);
						return await window.pageContext.Runtime.getPageContext(runtime);
					} finally {
						window.pageContext.Runtime.close(runtime);
						sibling.remove();
					}
				}, childOrigin),
			).toMatchObject({ url: `${childOrigin}/sibling` });
			expect((await context()).url).toBe(`${childOrigin}/`);

			const child = page
				.frames()
				.find((frame) => frame.url() === `${childOrigin}/`)!;
			for (const [action, expectedUrl] of [
				["navigate", `${childOrigin}/next?application=kept#section`],
				["reload", `${childOrigin}/next?application=kept#section`],
				["back", `${childOrigin}/`],
				["forward", `${childOrigin}/next?application=kept#section`],
			]) {
				await Promise.all([
					page.evaluate(
						() =>
							new Promise<void>((resolve) => {
								document
									.querySelector("iframe")!
									.addEventListener("load", () => resolve(), { once: true });
							}),
					),
					child.evaluate((action) => {
						if (action === "navigate")
							location.assign("/next?application=kept#section");
						if (action === "reload") location.reload();
						if (action === "back") history.back();
						if (action === "forward") history.forward();
					}, action),
				]);
				expect((await context()).url, action).toBe(expectedUrl);
			}

			const previousRuntime = await page.evaluateHandle(() =>
				window.pageContext.runtime(),
			);
			await page.evaluate(
				(url) => window.pageContext.mount(url, false),
				childOrigin,
			);
			await page.waitForFunction(
				() => window.pageContext.runtime() === undefined,
			);
			await page.evaluate((url) => window.pageContext.mount(url), childOrigin);
			await page.waitForFunction(
				() => window.pageContext.runtime() !== undefined,
			);
			expect(
				await page.evaluate(
					(previous) => window.pageContext.runtime() !== previous,
					previousRuntime,
				),
			).toBe(true);
			expect((await context()).url).toBe(
				`${childOrigin}/next?application=kept#section`,
			);
			expect(errors).toEqual([]);
		},
	);
});
