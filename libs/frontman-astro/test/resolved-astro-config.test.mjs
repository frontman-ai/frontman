import { describe, expect, test } from "vitest"
import { sanitizeResolvedAstroConfig } from "../src/tools/resolved-astro-config.mjs"

describe("sanitizeResolvedAstroConfig", () => {
  test.each([
    ["redis", "redis"],
    [
      { entrypoint: "unstorage/drivers/redis", config: { url: "redis://user:secret@localhost" } },
      { entrypoint: "unstorage/drivers/redis", config: "redacted" },
    ],
    [
      { entrypoint: new URL("file:///app/session-driver.mjs"), config: { token: "secret" } },
      { entrypoint: "file:///app/session-driver.mjs", config: "redacted" },
    ],
    [{ entrypoint: "unstorage/drivers/memory" }, { entrypoint: "unstorage/drivers/memory" }],
  ])("sanitizes session driver %j", (driver, expectedDriver) => {
    const sanitized = sanitizeResolvedAstroConfig({
      astroVersion: "7.1.6",
      buildOutput: "server",
      config: {
        session: {
          driver,
          options: { password: "secret" },
          ttl: 3600,
          cookie: { name: "session", secure: true },
        },
      },
    })

    expect(sanitized.session).toEqual({
      driver: expectedDriver,
      ttl: 3600,
      cookie: { name: "session", secure: true },
    })
    expect(JSON.stringify(sanitized)).not.toContain("secret")
  })

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
