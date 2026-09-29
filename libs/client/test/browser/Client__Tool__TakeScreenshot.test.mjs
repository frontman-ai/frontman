import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { createServer } from "vite";

let server;
let browser;
let origin;
before(async () => {
	server = await createServer({
		configFile: false,
		root: fileURLToPath(new URL("../../", import.meta.url)),
		server: { host: "127.0.0.1", port: 0, hmr: false },
		optimizeDeps: { noDiscovery: true },
		plugins: [
			{
				name: "screenshot-preview-fixture",
				configureServer(server) {
					server.middlewares.use((req, res, next) => {
						if (req.url !== "/") return next();
						res.setHeader("Content-Type", "text/html");
						res.end(
							'<!doctype html><body style="margin:0"><iframe style="border:0;transform-origin:top left"></iframe>',
						);
					});
				},
				load(id) {
					if (!id.endsWith("/Client__Tool__PreviewContext.res.mjs")) return;
					return `export const exnMessage = error => error.message;
					export const withPreview = (_onUnavailable, fn) => {
						const frame = document.querySelector('iframe');
						return fn({doc: frame.contentDocument, win: frame.contentWindow});
					};`;
				},
			},
		],
	});
	await server.listen();
	origin = `http://127.0.0.1:${server.httpServer.address().port}`;
	browser = await chromium.launch({ headless: true });
});
after(async () => {
	await browser?.close();
	await server?.close();
});

async function pixels(page, dataUrl, width, height) {
	return page.evaluate(
		async ({ dataUrl, width, height }) => {
			const image = new Image();
			image.src = dataUrl;
			await image.decode();
			const canvas = document.createElement("canvas");
			canvas.width = width ?? image.width;
			canvas.height = height ?? image.height;
			const ctx = canvas.getContext("2d");
			ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
			const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
			let left = Infinity,
				top = Infinity,
				right = -1,
				bottom = -1;
			for (let y = 0; y < canvas.height; y++) {
				for (let x = 0; x < canvas.width; x++) {
					const i = (y * canvas.width + x) * 4;
					if (data[i] > 200 && data[i + 1] < 50 && data[i + 2] < 50) {
						left = Math.min(left, x);
						top = Math.min(top, y);
						right = Math.max(right, x);
						bottom = Math.max(bottom, y);
					}
				}
			}
			return {
				size: [image.width, image.height],
				bounds: right < 0 ? null : [left, top, right, bottom],
			};
		},
		{ dataUrl, width, height },
	);
}

const cases = [
	{ name: "baseline" },
	{ name: "body margin", body: "margin:40px" },
	{ name: "HTML top margin", html: "margin-top:32px" },
	{
		name: "fixed header after scrolling",
		marker: "position:fixed;top:0",
		scrollY: 400,
	},
	{
		name: "sticky header after scrolling",
		marker: "position:sticky;top:0",
		scrollY: 400,
	},
	{ name: "fixed footer", marker: "position:fixed;bottom:0", scrollY: 400 },
	{
		name: "thin fixed footer",
		marker: "position:fixed;bottom:0;height:10px",
		scrollY: 400,
	},
	{
		name: "horizontal scroll",
		body: "width:1600px",
		marker: "position:fixed;left:0;top:0",
		scrollX: 400,
	},
	{ name: "short page", body: "height:200px" },
	{
		name: "long page retains viewport resolution",
		body: "height:16000px",
		marker: "position:fixed;top:0",
		scrollY: 8000,
	},
	{
		name: "scaled iframe",
		marker: "position:fixed;top:0",
		scrollY: 400,
		frameScale: 0.5,
	},
	{ name: "retina mobile", width: 375, dpr: 2, body: "margin:16px" },
	{
		name: "767px viewport",
		width: 767,
		marker: "position:fixed;bottom:0",
		scrollY: 400,
	},
	{
		name: "quirks mode",
		doctype: "",
		marker: "position:fixed;top:0",
		scrollY: 400,
	},
	{
		name: "oversized viewport respects image limit",
		width: 8000,
		expectedSize: [7680, 576],
	},
	{
		name: "selector capture",
		input: { selector: "#brand" },
		expectedSize: [100, 50],
	},
	{
		name: "full-page capture",
		input: { fullPage: true },
		expectedSize: [800, 1400],
	},
];

for (const fixture of cases) {
	test(fixture.name, { timeout: 30_000 }, async () => {
		const width = fixture.width ?? 800;
		const height = 600;
		const context = await browser.newContext({
			viewport: { width: 1200, height: 900 },
			deviceScaleFactor: fixture.dpr ?? 1,
		});
		try {
			const page = await context.newPage();
			await page.goto(origin);
			await page.locator("iframe").evaluate(
				(el, { width, height, scale }) => {
					el.style.width = `${width}px`;
					el.style.height = `${height}px`;
					el.style.transform = `scale(${scale})`;
				},
				{ width, height, scale: fixture.frameScale ?? 1 },
			);
			const frame = page.frames()[1];
			await frame.setContent(`${fixture.doctype ?? "<!doctype html>"}<style>
				html{background:white;${fixture.html ?? ""}}
				body{margin:0;background:white;height:1400px;${fixture.body ?? ""}}
				#brand{width:100px;height:50px;background:rgb(255,0,0);${fixture.marker ?? ""}}
				</style><div id="brand"></div>`);
			await frame.evaluate(({ x, y }) => scrollTo(x, y), {
				x: fixture.scrollX ?? 0,
				y: fixture.scrollY ?? 0,
			});
			await frame.evaluate(
				() =>
					new Promise((resolve) =>
						requestAnimationFrame(() => requestAnimationFrame(resolve)),
					),
			);
			const before = await frame.evaluate(() => ({
				scrollX,
				scrollY,
				rect: document.querySelector("#brand").getBoundingClientRect().toJSON(),
			}));
			const native = await page.locator("iframe").screenshot();
			const result = await page.evaluate(async (input) => {
				const { execute } = await import(
					"/src/tools/Client__Tool__TakeScreenshot.res.mjs"
				);
				return execute(input, "screenshot-test", "capture-test");
			}, fixture.input ?? {});
			assert.notEqual(result.isError, true, JSON.stringify(result));
			const image = result.content.find(
				(part) => part.TAG === "ImageContent",
			)?._0;
			assert.ok(image, "Tool must return image content");
			assert.equal(image.mimeType, "image/jpeg");
			const actual = await pixels(
				page,
				`data:${image.mimeType};base64,${image.data}`,
			);
			assert.deepEqual(actual.size, fixture.expectedSize ?? [width, height]);
			assert.ok(actual.bounds, "Visible marker disappeared from screenshot");
			if (!fixture.input) {
				const expected = await pixels(
					page,
					`data:image/png;base64,${native.toString("base64")}`,
					...actual.size,
				);
				assert.ok(expected.bounds, "Native screenshot must contain the marker");
				actual.bounds.forEach((value, i) =>
					assert.ok(
						Math.abs(value - expected.bounds[i]) <= 2,
						`Marker bounds ${actual.bounds} differ from native ${expected.bounds}`,
					),
				);
			}
			const after = await frame.evaluate(() => ({
				scrollX,
				scrollY,
				rect: document.querySelector("#brand").getBoundingClientRect().toJSON(),
			}));
			assert.deepEqual(after, before, "Capture must not move the live page");
		} finally {
			await context.close();
		}
	});
}
