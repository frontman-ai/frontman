import {describe, expect, test} from "vitest"

import {canonicalizeFrontmanUrl} from "../src/astro-route-rewrite.mjs"

describe("canonicalizeFrontmanUrl", () => {
  test.each([
    ["/frontman", "always", "/frontman/"],
    ["/frontman/tools?name=pages", "always", "/frontman/tools/?name=pages"],
    ["/docs/frontman", "always", "/docs/frontman/"],
    ["/frontman/", "never", "/frontman"],
    ["/frontman/tools/?name=pages", "never", "/frontman/tools?name=pages"],
    ["/docs/frontman/", "never", "/docs/frontman"],
    ["/frontman/", "ignore", "/frontman/"],
    ["/frontman", "ignore", "/frontman"],
  ])("canonicalizes %s with %s policy", (url, policy, expected) => {
    expect(canonicalizeFrontmanUrl(url, "frontman", policy)).toBe(expected)
  })

  test("preserves unrelated and similarly prefixed paths", () => {
    expect(canonicalizeFrontmanUrl("/docs", "frontman", "always")).toBe("/docs")
    expect(canonicalizeFrontmanUrl("/frontman-copy", "frontman", "always")).toBe("/frontman-copy")
  })
})
