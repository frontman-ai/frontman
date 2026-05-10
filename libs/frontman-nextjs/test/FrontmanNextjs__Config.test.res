open Vitest

module Config = FrontmanNextjs__Config
module Path = FrontmanBindings.Path

describe("Config root normalization", () => {
  test("normalizes omitted roots to absolute paths", t => {
    let config = Config.make()

    t->expect(Path.isAbsolute(config.projectRoot))->Expect.toBe(true)
    t->expect(Path.isAbsolute(config.sourceRoot))->Expect.toBe(true)
    t->expect(config.projectRoot == ".")->Expect.toBe(false)
    t->expect(config.sourceRoot == ".")->Expect.toBe(false)
  })

  test("resolves relative sourceRoot against projectRoot", t => {
    let projectRoot = Path.resolve(".")
    let config = Config.make(~projectRoot=Some(projectRoot), ~sourceRoot=Some("."))

    t->expect(config.sourceRoot)->Expect.toBe(projectRoot)
  })
})
