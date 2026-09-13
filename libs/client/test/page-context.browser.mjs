import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { firefox } from "playwright";
import { build } from "vite";

const bundles = await build({
	configFile: false,
	build: {
		lib: {
			entry: fileURLToPath(
				new URL("./Client__PageContextBrowser.res.mjs", import.meta.url),
			),
			formats: ["es"],
		},
		write: false,
		minify: false,
	},
	define: { "process.env.NODE_ENV": '"test"', __PACKAGE_VERSION__: '"test"' },
});
const parentBundle = bundles[0].output.find(
	(output) => output.type === "chunk" && output.isEntry,
).code;
const bridge = await readFile(
	new URL("../../frontman-preview-bridge/dist/bridge.js", import.meta.url),
);
const servers = [];
let browser;
try {
	const serve = async (handler) => {
		const server = createServer(handler);
		servers.push(server);
		await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
		return `http://127.0.0.1:${server.address().port}`;
	};
	const parentOrigin = await serve((req, res) => {
		res.setHeader(
			"Content-Type",
			req.url === "/test.js" ? "text/javascript" : "text/html",
		);
		res.end(
			req.url === "/test.js"
				? parentBundle
				: '<title>Parent shell</title><script>window.__frontmanRuntime={framework:"vite",basePath:"frontman"}</script>',
		);
	});
	const childOrigin = await serve((req, res) => {
		res.setHeader(
			"Content-Type",
			req.url === "/bridge.js" ? "text/javascript" : "text/html",
		);
		res.end(
			req.url === "/bridge.js"
				? bridge
				: `<title>Cross-origin child</title><main>Preview</main><script src="/bridge.js" data-frontman-parent-origin="${parentOrigin}" data-frontman-channel="browser-test"></script>`,
		);
	});
	assert.notEqual(parentOrigin, childOrigin);
	browser = await firefox.launch({ headless: true });
	const page = await browser.newPage({ colorScheme: "dark" });
	const errors = [];
	page.on("pageerror", (error) => errors.push(error.message));
	await page.goto(parentOrigin);
	await page.evaluate(async (childOrigin) => {
		const iframe = document.createElement("iframe");
		const loaded = new Promise((resolve) =>
			iframe.addEventListener("load", resolve, { once: true }),
		);
		iframe.src = childOrigin;
		document.body.appendChild(iframe);
		await loaded;
		let blocked = false;
		try {
			void iframe.contentWindow.BS_PRIVATE_NESTED_SOME_NONE;
		} catch (error) {
			blocked = error.name === "SecurityError";
		}
		if (!blocked)
			throw new Error("Expected Firefox to block the old option marker access");
		const { run } = await import("/test.js");
		await run(iframe, childOrigin);
		iframe.remove();
	}, childOrigin);
	assert.deepEqual(errors, []);
	console.log(
		"PASS: Firefox cross-origin bootstrap, typed page context, prompt enrichment, task isolation, and disconnected fallback",
	);
} finally {
	await browser?.close();
	await Promise.all(
		servers.map(
			(server) =>
				new Promise((resolve, reject) =>
					server.close((error) => (error ? reject(error) : resolve())),
				),
		),
	);
}
