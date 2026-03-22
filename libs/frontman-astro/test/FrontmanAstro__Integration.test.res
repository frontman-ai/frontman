open Vitest

module Integration = FrontmanAstro__Integration

describe("parseMajorVersion", _t => {
  test("standard semver", t => {
    t->expect(Integration.parseMajorVersion("5.17.2"))->Expect.toBe(5)
  })

  test("prerelease suffix", t => {
    t->expect(Integration.parseMajorVersion("6.0.0-beta.1"))->Expect.toBe(6)
  })

  test("throws on empty string", t => {
    t->expect(() => Integration.parseMajorVersion(""))->Expect.toThrow
  })

  test("throws on garbage", t => {
    t->expect(() => Integration.parseMajorVersion("nope"))->Expect.toThrow
  })
})

describe("getAstroVersion", _t => {
  test("reads installed astro version", t => {
    let version = Integration.getAstroVersion()
    t->expect(version->String.length > 0)->Expect.toBe(true)
  })

  test("getAstroMajorVersion returns >= 5", t => {
    t->expect(Integration.getAstroMajorVersion() >= 5)->Expect.toBe(true)
  })
})
