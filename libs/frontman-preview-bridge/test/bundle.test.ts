import { readdir, readFile } from "node:fs/promises";
import { runInNewContext } from "node:vm";
import { describe, expect, test } from "vitest";

describe("classic bridge bundle", () => {
	test("emits self-contained classic bridge and loader artifacts", async () => {
		expect((await readdir("dist")).sort()).toEqual([
			"bridge.js",
			"preview-loader.js",
		]);
		for (const name of ["bridge.js", "preview-loader.js"]) {
			const bundle = await readFile(`dist/${name}`, "utf8");
			expect(bundle).not.toMatch(/\bimport\s*(?:\(|["'{*])/);
			expect(bundle).not.toMatch(
				/\bexport\s+(?:default|\{|const|function|class)/,
			);
		}
	});

	test("bootstraps once per document without URL changes or shared storage", async () => {
		const loader = await readFile("dist/preview-loader.js", "utf8");
		function load(name: string, topLevel = false) {
			const scripts: Record<string, unknown>[] = [];
			const window: Record<string, unknown> = {
				name,
				parent: {},
				location: new URL("https://child.test/private"),
			};
			if (topLevel) window.parent = window;
			const document = {
				currentScript: {
					src: "https://child.test/blog/assets/preview-loader.js",
				},
				querySelector: () => scripts[0],
				createElement: () => ({
					setAttribute(
						this: Record<string, unknown>,
						key: string,
						value: string,
					) {
						this[key] = value;
					},
				}),
				head: {
					appendChild: (script: Record<string, unknown>) =>
						scripts.push(script),
				},
			};
			const context = { window, document, URL, console };
			runInNewContext(loader, context);
			runInNewContext(loader, context);
			return scripts;
		}
		for (const channel of ["first", "second", "first"]) {
			const config = `frontman:https://child.test/?channel=${channel}`;
			const scripts = load(config);
			expect(scripts).toHaveLength(1);
			expect(scripts[0]).toMatchObject({
				src: "https://child.test/blog/assets/bridge.js",
				"data-frontman-parent-origin": "https://child.test",
				"data-frontman-channel": channel,
			});
		}
		for (const origin of [
			"https://attacker.test",
			"http://child.test",
			"https://child.test:8443",
		]) {
			expect(load(`frontman:${origin}/?channel=first`)).toEqual([]);
		}
		expect(load("")).toEqual([]);
		expect(load("frontman:https://parent.test/?channel=first", true)).toEqual(
			[],
		);
		expect(() => load("frontman:https://parent.test/")).toThrow(
			"Invalid Frontman",
		);
		expect(() => load("frontman:file:///?channel=first")).toThrow(
			"Invalid Frontman",
		);
	});
});
