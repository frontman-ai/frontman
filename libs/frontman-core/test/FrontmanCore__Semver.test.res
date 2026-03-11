open Vitest

module Semver = FrontmanCore__Semver

// -- parse --------------------------------------------------------------------

describe("parse", () => {
  test("parses a valid semver string", t => {
    t
    ->expect(Semver.parse("1.2.3"))
    ->Expect.toEqual(Some({major: 1, minor: 2, patch: 3, prerelease: false}))
  })

  test("parses 0.0.0", t => {
    t
    ->expect(Semver.parse("0.0.0"))
    ->Expect.toEqual(Some({major: 0, minor: 0, patch: 0, prerelease: false}))
  })

  test("strips pre-release suffix and sets flag", t => {
    t
    ->expect(Semver.parse("1.0.0-beta.1"))
    ->Expect.toEqual(Some({major: 1, minor: 0, patch: 0, prerelease: true}))
  })

  test("strips complex pre-release suffix", t => {
    t
    ->expect(Semver.parse("2.1.3-alpha.0.rc.1"))
    ->Expect.toEqual(Some({major: 2, minor: 1, patch: 3, prerelease: true}))
  })

  test("returns None for malformed input", t => {
    t->expect(Semver.parse("abc"))->Expect.toBeNone
  })

  test("returns None for empty string", t => {
    t->expect(Semver.parse(""))->Expect.toBeNone
  })

  test("returns None for two-part version", t => {
    t->expect(Semver.parse("1.2"))->Expect.toBeNone
  })

  test("returns None for four-part version", t => {
    t->expect(Semver.parse("1.2.3.4"))->Expect.toBeNone
  })

  test("returns None for non-numeric parts", t => {
    t->expect(Semver.parse("a.b.c"))->Expect.toBeNone
  })
})

// -- isBehind -----------------------------------------------------------------

describe("isBehind", () => {
  test("returns false for equal versions", t => {
    let v = {Semver.major: 1, minor: 2, patch: 3, prerelease: false}
    t->expect(Semver.isBehind(v, v))->Expect.toBe(false)
  })

  test("detects behind on major", t => {
    let installed = {Semver.major: 1, minor: 0, patch: 0, prerelease: false}
    let latest = {Semver.major: 2, minor: 0, patch: 0, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(true)
  })

  test("detects behind on minor", t => {
    let installed = {Semver.major: 1, minor: 2, patch: 0, prerelease: false}
    let latest = {Semver.major: 1, minor: 3, patch: 0, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(true)
  })

  test("detects behind on patch", t => {
    let installed = {Semver.major: 1, minor: 2, patch: 3, prerelease: false}
    let latest = {Semver.major: 1, minor: 2, patch: 4, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(true)
  })

  test("returns false when ahead on major", t => {
    let installed = {Semver.major: 3, minor: 0, patch: 0, prerelease: false}
    let latest = {Semver.major: 2, minor: 9, patch: 9, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(false)
  })

  test("returns false when ahead on minor", t => {
    let installed = {Semver.major: 1, minor: 5, patch: 0, prerelease: false}
    let latest = {Semver.major: 1, minor: 3, patch: 9, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(false)
  })

  test("returns false when ahead on patch", t => {
    let installed = {Semver.major: 1, minor: 2, patch: 5, prerelease: false}
    let latest = {Semver.major: 1, minor: 2, patch: 3, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(false)
  })

  test("pre-release is behind same release version (1.0.0-beta < 1.0.0)", t => {
    let installed = {Semver.major: 1, minor: 0, patch: 0, prerelease: true}
    let latest = {Semver.major: 1, minor: 0, patch: 0, prerelease: false}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(true)
  })

  test("release is not behind pre-release of same version", t => {
    let installed = {Semver.major: 1, minor: 0, patch: 0, prerelease: false}
    let latest = {Semver.major: 1, minor: 0, patch: 0, prerelease: true}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(false)
  })

  test("two pre-releases of same version are equal (not behind)", t => {
    let installed = {Semver.major: 1, minor: 0, patch: 0, prerelease: true}
    let latest = {Semver.major: 1, minor: 0, patch: 0, prerelease: true}
    t->expect(Semver.isBehind(installed, latest))->Expect.toBe(false)
  })
})
