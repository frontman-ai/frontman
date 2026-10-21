import {readdir, readFile} from "node:fs/promises"
import {describe, expect, test} from "vitest"

describe("classic bridge bundle", () => {
	test("emits a self-contained bridge.js artifact and dependency notices", async () => {
		expect((await readdir("dist")).sort()).toEqual(["bridge-licenses.txt", "bridge.js"])
		const notices = await readFile("dist/bridge-licenses.txt", "utf8")
		for (const author of ["BlueHotDog", "Bloomberg Finance L.P.", "Dmitry Zakharov"]) {
			expect(notices).toContain(author)
		}
		expect(notices).toContain("Permission is hereby granted")

		const bundle = await readFile("dist/bridge.js", "utf8")
		expect(bundle).not.toMatch(/\bimport\s*(?:\(|["'{*])/)
		expect(bundle).not.toMatch(/\bexport\s+(?:default|\{|const|function|class)/)
	})
})
