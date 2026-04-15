open Vitest

// _getBasePath() falls back to "frontman" in test environments (no window.__frontmanRuntime).
// All cases below use "frontman" as the basePath.

module BrowserUrl = Client__BrowserUrl

// ── hasSuffix ────────────────────────────────────────────────────────────

describe("hasSuffix", () => {
  test("detects exact suffix", t => {
    t->expect(BrowserUrl.hasSuffix("/frontman"))->Expect.toBe(true)
  })

  test("detects suffix with trailing slash", t => {
    t->expect(BrowserUrl.hasSuffix("/frontman/"))->Expect.toBe(true)
  })

  test("detects suffix with path prefix", t => {
    t->expect(BrowserUrl.hasSuffix("/blog/frontman"))->Expect.toBe(true)
  })

  test("detects suffix with path prefix and trailing slash", t => {
    t->expect(BrowserUrl.hasSuffix("/blog/frontman/"))->Expect.toBe(true)
  })

  test("detects double suffix", t => {
    t->expect(BrowserUrl.hasSuffix("/frontman/frontman"))->Expect.toBe(true)
  })

  test("returns false for locale path without trailing slash — the bug case", t => {
    t->expect(BrowserUrl.hasSuffix("/en"))->Expect.toBe(false)
  })

  test("returns false for locale path with trailing slash", t => {
    t->expect(BrowserUrl.hasSuffix("/en/"))->Expect.toBe(false)
  })

  test("returns false for root", t => {
    t->expect(BrowserUrl.hasSuffix("/"))->Expect.toBe(false)
  })

  test("returns false for clean path without trailing slash", t => {
    t->expect(BrowserUrl.hasSuffix("/blog"))->Expect.toBe(false)
  })

  test("returns false for partial match (no leading slash before basePath)", t => {
    t->expect(BrowserUrl.hasSuffix("/notfrontman"))->Expect.toBe(false)
  })
})

// ── stripSuffix ──────────────────────────────────────────────────────────

describe("stripSuffix", () => {
  // When suffix is present — should strip and add trailing slash

  test("strips exact suffix to root", t => {
    t->expect(BrowserUrl.stripSuffix("/frontman"))->Expect.toBe("/")
  })

  test("strips suffix with trailing slash to root", t => {
    t->expect(BrowserUrl.stripSuffix("/frontman/"))->Expect.toBe("/")
  })

  test("strips suffix preserving path prefix", t => {
    t->expect(BrowserUrl.stripSuffix("/blog/frontman"))->Expect.toBe("/blog/")
  })

  test("strips suffix with trailing slash preserving path prefix", t => {
    t->expect(BrowserUrl.stripSuffix("/blog/frontman/"))->Expect.toBe("/blog/")
  })

  test("strips double suffix", t => {
    t->expect(BrowserUrl.stripSuffix("/frontman/frontman"))->Expect.toBe("/")
  })

  // When no suffix present — must return original pathname unchanged (the bug fix)

  test("returns locale path unchanged — no trailing slash added", t => {
    t->expect(BrowserUrl.stripSuffix("/en"))->Expect.toBe("/en")
  })

  test("returns locale path with trailing slash unchanged", t => {
    t->expect(BrowserUrl.stripSuffix("/en/"))->Expect.toBe("/en/")
  })

  test("returns root unchanged", t => {
    t->expect(BrowserUrl.stripSuffix("/"))->Expect.toBe("/")
  })

  test("returns clean path without trailing slash unchanged", t => {
    t->expect(BrowserUrl.stripSuffix("/blog"))->Expect.toBe("/blog")
  })

  test("returns partial match unchanged", t => {
    t->expect(BrowserUrl.stripSuffix("/notfrontman"))->Expect.toBe("/notfrontman")
  })
})

// ── removeTrailingSlash ──────────────────────────────────────────────────

describe("removeTrailingSlash", () => {
  test("removes trailing slash from path", t => {
    t->expect(BrowserUrl.removeTrailingSlash("/en/"))->Expect.toBe("/en")
  })

  test("removes trailing slash from nested path", t => {
    t->expect(BrowserUrl.removeTrailingSlash("/blog/post/"))->Expect.toBe("/blog/post")
  })

  test("leaves path without trailing slash unchanged", t => {
    t->expect(BrowserUrl.removeTrailingSlash("/en"))->Expect.toBe("/en")
  })

  test("leaves root slash unchanged", t => {
    t->expect(BrowserUrl.removeTrailingSlash("/"))->Expect.toBe("/")
  })

  test("removes trailing slash from full URL", t => {
    t
    ->expect(BrowserUrl.removeTrailingSlash("http://localhost:3000/en/"))
    ->Expect.toBe("http://localhost:3000/en")
  })
})
