// Tests for shared case-insensitive filename pattern matching.

open Vitest

module FilenamePattern = FrontmanCore__FilenamePattern

describe("FilenamePattern.matchesPattern", _t => {
  test("empty pattern matches everything", t => {
    t->expect(FilenamePattern.matchesPattern(~pattern="", ~text="anything.js"))->Expect.toBe(true)
  })

  test("supports substring matching", t => {
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="config", ~text="config.json"))
    ->Expect.toBe(true)
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="config", ~text="readme.md"))
    ->Expect.toBe(false)
  })

  test("is case-insensitive", t => {
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="config", ~text="Config.json"))
    ->Expect.toBe(true)
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="config", ~text="CONFIG.ts"))
    ->Expect.toBe(true)
  })

  test("supports leading wildcard", t => {
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="*.test.ts", ~text="app.test.ts"))
    ->Expect.toBe(true)
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="*.test.ts", ~text="test.js"))
    ->Expect.toBe(false)
  })

  test("supports multiple wildcards", t => {
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="*.config.*", ~text="app.config.ts"))
    ->Expect.toBe(true)
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="*.config.*", ~text="test.config.js"))
    ->Expect.toBe(true)
    t
    ->expect(FilenamePattern.matchesPattern(~pattern="*.config.*", ~text="config.json"))
    ->Expect.toBe(false)
  })
})
