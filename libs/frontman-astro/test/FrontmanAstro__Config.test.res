open Vitest

module Config = FrontmanAstro__Config
module Path = FrontmanBindings.Path

describe("Config root normalization", () => {
  test("normalizes omitted roots to absolute paths", t => {
    let config = Config.makeFromObject({})

    t->expect(Path.isAbsolute(config.projectRoot))->Expect.toBe(true)
    t->expect(Path.isAbsolute(config.sourceRoot))->Expect.toBe(true)
    t->expect(config.projectRoot == ".")->Expect.toBe(false)
    t->expect(config.sourceRoot == ".")->Expect.toBe(false)
  })

  test("resolves relative sourceRoot against projectRoot", t => {
    let projectRoot = Path.resolve(".")
    let config = Config.makeFromObject({projectRoot, sourceRoot: "."})

    t->expect(config.sourceRoot)->Expect.toBe(projectRoot)
  })
})
