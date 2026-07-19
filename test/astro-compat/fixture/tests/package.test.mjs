import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"

import frontman, {frontmanIntegration} from "@frontman-ai/astro"

test("packed package exposes Astro integration entry points", () => {
  assert.equal(frontman, frontmanIntegration)

  const integration = frontman({projectRoot: import.meta.dirname})
  assert.equal(integration.name, "frontman")
  assert.equal(typeof integration.hooks["astro:config:setup"], "function")
})

test("packed package declares supported Astro and Node versions", async () => {
  const entryUrl = import.meta.resolve("@frontman-ai/astro")
  const packageJson = JSON.parse(await readFile(new URL("../package.json", entryUrl), "utf8"))

  assert.equal(packageJson.engines.node, ">=22.19.0")
  assert.equal(packageJson.peerDependencies.astro, "^5.0.0 || ^6.0.0 || ^7.0.0")
})
