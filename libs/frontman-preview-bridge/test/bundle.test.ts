import {readdir, readFile} from "node:fs/promises"
import {runInNewContext} from "node:vm"
import {describe, expect, test} from "vitest"

describe("classic bridge bundle", () => {
	test("is inert for old clients, top-level pages and foreign frame origins", async () => {
		const bundle = await readFile("dist/bridge.js", "utf8")
		for (const name of ["", "application-frame", "frontman:https://attacker.test/?channel=task"]) {
			const window = {name, location: new URL("https://site.test/"), parent: {}}
			expect(() => runInNewContext(bundle, {window, URL})).not.toThrow()
		}
		const window: Record<string, unknown> = {
			name: "frontman:https://site.test/?channel=task",
			location: new URL("https://site.test/"),
		}
		window.parent = window
		expect(() => runInNewContext(bundle, {window, URL})).not.toThrow()
	})

	test("emits one self-contained bridge.js artifact", async () => {
		expect(await readdir("dist")).toEqual(["bridge.js"])

		const bundle = await readFile("dist/bridge.js", "utf8")
		expect(bundle).not.toMatch(/\bimport\s*(?:\(|["'{*])/)
		expect(bundle).not.toMatch(/\bexport\s+(?:default|\{|const|function|class)/)
	})
})
