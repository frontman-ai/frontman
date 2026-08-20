import {readdir, readFile} from "node:fs/promises"
import {describe, expect, test} from "vitest"

describe("classic bridge bundle", () => {
	test("emits one self-contained bridge.js artifact", async () => {
		expect(await readdir("dist")).toEqual(["bridge.js"])

		const bundle = await readFile("dist/bridge.js", "utf8")
		expect(bundle).not.toMatch(/\bimport\s*(?:\(|["'{*])/)
		expect(bundle).not.toMatch(/\bexport\s+(?:default|\{|const|function|class)/)
	})
})
