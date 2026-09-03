import { describe, expect, test } from "vitest"
import { sanitizeResolvedAstroConfig } from "../src/tools/resolved-astro-config.mjs"

describe("sanitizeResolvedAstroConfig", () => {
  test("redacts image service config and surfaces serialization errors", () => {
    const sanitized = sanitizeResolvedAstroConfig({
      astroVersion: "5.18.0",
      buildOutput: "server",
      config: {
        base: "/",
        trailingSlash: "ignore",
        integrations: [],
        image: { service: { entrypoint: "svc", config: { token: "secret" } } },
        redirects: { count: 1n },
      },
    })

    expect(sanitized.image.service).toEqual({ entrypoint: "svc", config: "redacted" })
    expect(JSON.stringify(sanitized)).not.toContain("secret")
    expect(sanitized.redirects.serializationError).toBe("Unable to serialize value")
  })
})
