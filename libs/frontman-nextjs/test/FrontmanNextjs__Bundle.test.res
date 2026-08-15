open Vitest

module Fs = FrontmanBindings.Fs
module Path = FrontmanBindings.Path
module Process = FrontmanBindings.Process

describe("server bundle runtime dependencies", _ => {
  let bundle = Fs.readFileSync(Path.join([Process.cwd(), "dist", "index.js"]))

  test("does not bundle ripgrep platform resolution", t => {
    t->expect(bundle->String.includes("platformPkg = `@vscode/ripgrep-"))->Expect.toBe(false)
    t->expect(bundle->String.includes("import(ripgrepModule)"))->Expect.toBe(false)
    t->expect(bundle->String.includes("runtimeRequire(specifier)"))->Expect.toBe(false)
  })

  test("does not bundle source-map WASM loading", t => {
    t->expect(bundle->String.includes("mappings.wasm"))->Expect.toBe(false)
  })
})
