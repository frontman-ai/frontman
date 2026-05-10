open Vitest

module ConfigRoots = FrontmanCore__ConfigRoots
module CorePath = FrontmanCore__Path
module Path = FrontmanBindings.Path

describe("ConfigRoots", () => {
  test("normalizes project roots to absolute paths", t => {
    let root = ConfigRoots.normalizeProjectRoot(".")

    t->expect(Path.isAbsolute(root))->Expect.toBe(true)
  })

  test("resolves relative source roots against project root", t => {
    let projectRoot = Path.resolve(".")
    let sourceRoot = ConfigRoots.normalizeSourceRoot(~projectRoot)("src")

    t->expect(sourceRoot)->Expect.toBe(Path.join([projectRoot, "src"]))
  })

  test("resolves typed relative source roots against project root", t => {
    let projectRoot = Path.resolve(".")
    let sourceRoot = ConfigRoots.normalizeSourceRootPath(~projectRoot, CorePath.relative("src"))

    t->expect(sourceRoot)->Expect.toBe(Path.join([projectRoot, "src"]))
  })

  test("defaults missing source root to project root", t => {
    let projectRoot = Path.resolve(".")
    let sourceRoot = ConfigRoots.sourceRootOrProjectRoot(~projectRoot, None)

    t->expect(sourceRoot)->Expect.toBe(projectRoot)
  })
})
