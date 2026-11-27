import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { once } from "node:events";
import { chromium } from "playwright";

const expected = process.argv[2];
const bundle = await readFile(new URL("../../dist/frontman.es.js", import.meta.url), "utf8");
const browser = await chromium.launch();
const server = createServer((_, res) => res.end("<html><head><script></script></head><body></body></html>"));
try {
	server.listen(0, "127.0.0.1");
	await once(server, "listening");
	const page = await browser.newPage();
	await page.goto(`http://127.0.0.1:${server.address().port}`);
	await page.context().setOffline(true);
	await page.evaluate(async (source) => {
		await import(URL.createObjectURL(new Blob([source], { type: "text/javascript" })));
	}, bundle);
	const scripts = await page.locator('script[src*="heap-api.com"]').evaluateAll((nodes) => nodes.map((node) => node.src));
	assert.deepEqual(scripts, [`https://cdn.us.heap-api.com/config/${expected}/heap_config.js`]);
	assert.equal(await page.evaluate(() => window.heap?.envId), expected);
} finally {
	await browser.close();
	server.close();
}
