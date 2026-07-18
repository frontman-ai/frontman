import assert from "node:assert/strict"
import test from "node:test"

import frontman, {frontmanIntegration} from "@frontman-ai/astro"

test("packed package exposes Astro integration entry points", () => {
  assert.equal(frontman, frontmanIntegration)

  const integration = frontman({projectRoot: import.meta.dirname})
  assert.equal(integration.name, "frontman")
  assert.equal(typeof integration.hooks["astro:config:setup"], "function")
})
