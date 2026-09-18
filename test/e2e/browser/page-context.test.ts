import { readFileSync } from "node:fs";
import { chromium, firefox, webkit } from "playwright";
import { expect, it, onTestFinished } from "vitest";
import { openPreview } from "../helpers/page-context.js";

const asset = (name: string) =>
	readFileSync(
		new URL(`../../../libs/frontman-wordpress/assets/${name}`, import.meta.url),
		"utf8",
	);
const childOrigin = "https://preview.test";
const foreignOrigin = "https://other.test";
const assetPath = "/blog/wp-content/plugins/frontman/assets";
const markup = `<!doctype html><title>Same-origin child</title><meta name="astro-view-transitions-enabled"><body><a href="/next?application=kept#section">Next</a><script src="${assetPath}/preview-loader.js"></script>`;

it.each([
	["Chromium", chromium],
	["Firefox", firefox],
	["WebKit", webkit],
] as const)(
	"page context lifecycle and origin checks: %s",
	async (_name, engine) => {
		const browser = await engine.launch();
		onTestFinished(() => browser.close());
		const page = await browser.newPage({ colorScheme: "dark" });
		const context = async () => {
			await page.waitForFunction(
				() => window.pageContext.runtime() !== undefined,
			);
			return page.evaluate(() => window.pageContext.context());
		};
		const errors: Error[] = [];
		page.on("pageerror", (error) => errors.push(error));
		for (const origin of [childOrigin, foreignOrigin]) {
			await page.route(`${origin}/**`, (route) =>
				route.fulfill({ contentType: "text/html", body: markup }),
			);
			for (const name of ["bridge.js", "preview-loader.js"]) {
				await page.route(`${origin}${assetPath}/${name}`, (route) =>
					route.fulfill({ contentType: "text/javascript", body: asset(name) }),
				);
			}
		}
		await openPreview(page, childOrigin);
		expect(await context()).toMatchObject({
			title: "Same-origin child",
			url: `${childOrigin}/`,
			colorScheme: "dark",
			astroClientRouting: "enabled",
		});
		expect(
			await page.evaluate(async (childOrigin) => {
				const sibling = document.createElement("iframe");
				sibling.name = `frontman:${childOrigin}/?channel=sibling`;
				const loaded = new Promise((resolve) =>
					sibling.addEventListener("load", resolve, { once: true }),
				);
				sibling.src = `${childOrigin}/sibling`;
				document.body.appendChild(sibling);
				await loaded;
				const { Runtime } = window.pageContext;
				const runtime = Runtime.make(sibling, childOrigin, "sibling");
				try {
					await Runtime.whenOpen(runtime);
					return await Runtime.getPageContext(runtime);
				} finally {
					Runtime.close(runtime);
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

		for (const claimedOrigin of [childOrigin, foreignOrigin]) {
			const status = await page.evaluate(
				async ({ foreignOrigin, claimedOrigin }) => {
					const iframe = document.createElement("iframe");
					iframe.name = `frontman:${claimedOrigin}/?channel=attack`;
					iframe.src = `${foreignOrigin}/private`;
					const loaded = new Promise((resolve) =>
						iframe.addEventListener("load", resolve, { once: true }),
					);
					document.body.appendChild(iframe);
					await loaded;
					const { Runtime } = window.pageContext;
					const runtime = Runtime.make(iframe, foreignOrigin, "attack");
					try {
						return await new Promise((resolve) =>
							Runtime.onStatus(runtime, resolve),
						);
					} finally {
						Runtime.close(runtime);
						iframe.remove();
					}
				},
				{ foreignOrigin, claimedOrigin },
			);
			expect(
				status,
				`Parent claiming ${claimedOrigin} must not connect`,
			).toEqual({
				TAG: "Disconnected",
				_0: "Window transport readiness timed out",
			});
		}
		expect(errors).toEqual([]);
	},
);
