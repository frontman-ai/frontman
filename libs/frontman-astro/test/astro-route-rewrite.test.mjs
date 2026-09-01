import {describe, expect, test} from "vitest"

import {
  canonicalizeFrontmanUrl,
  isExactMcpRequest,
  prepareFrontmanRequest,
} from "../src/astro-route-rewrite.mjs"

describe("canonicalizeFrontmanUrl", () => {
  test.each([
    ["/frontman", "always", "/frontman/"],
    [
      "/frontman/resolve-source-location?component=Page",
      "always",
      "/frontman/resolve-source-location/?component=Page",
    ],
    ["/docs/frontman", "always", "/docs/frontman/"],
    ["/frontman/", "never", "/frontman"],
    [
      "/frontman/resolve-source-location/?component=Page",
      "never",
      "/frontman/resolve-source-location?component=Page",
    ],
    ["/docs/frontman/", "never", "/docs/frontman"],
    ["/frontman/", "ignore", "/frontman/"],
    ["/frontman", "ignore", "/frontman"],
  ])("canonicalizes %s with %s policy", (url, policy, expected) => {
    expect(canonicalizeFrontmanUrl(url, "frontman", policy)).toBe(expected)
  })

  test("preserves unrelated and similarly prefixed paths", () => {
    expect(canonicalizeFrontmanUrl("/docs", "frontman", "always")).toBe("/docs")
    expect(canonicalizeFrontmanUrl("/frontman-copy", "frontman", "always")).toBe("/frontman-copy")
    expect(canonicalizeFrontmanUrl("/mcp", "frontman", "always")).toBe("/mcp")
    expect(canonicalizeFrontmanUrl("/mcp/", "frontman", "never")).toBe("/mcp/")
  })
})

describe("prepareFrontmanRequest", () => {
  test.each(["always", "never"])("preserves exact MCP ownership with %s policy", trailingSlash => {
    const request = {url: "/mcp?request=1"}
    prepareFrontmanRequest(request, "frontman", trailingSlash, true)
    expect(isExactMcpRequest(request)).toBe(true)
    expect(request.url).not.toMatch(/^\/mcp(?:\?|$)/)
  })

  test("does not grant MCP ownership to aliases", () => {
    for (const url of ["/mcp/", "/MCP", "/__frontman_exact_mcp"]) {
      const request = {url}
      prepareFrontmanRequest(request, "frontman", "always", true)
      expect(isExactMcpRequest(request)).toBe(false)
    }
  })

  test("leaves MCP paths unowned when MCP is disabled", () => {
    const request = {url: "/mcp"}
    prepareFrontmanRequest(request, "frontman", "always", false)
    expect(request.url).toBe("/mcp")
    expect(isExactMcpRequest(request)).toBe(false)
  })
})
