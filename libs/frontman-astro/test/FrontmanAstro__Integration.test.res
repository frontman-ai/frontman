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

describe("browser instrumentation", () => {
  test("injects the navigation module only during development", t => {
    let scripts = ref([])
    let setup = Integration.make({}).hooks.configSetup->Option.getOrThrow
    let context: FrontmanBindings.Astro.configSetupHookContext = {
      addDevToolbarApp: _ => (),
      injectScript: (stage, source) => scripts := scripts.contents->Array.concat([(stage, source)]),
      updateConfig: _ => (),
      config: {
        root: "/project/",
        base: "/",
        devToolbar: {enabled: true},
        markdown: {rehypePlugins: []},
        trailingSlash: #ignore,
      },
      command: #build,
    }
    setup(context)
    t->expect(scripts.contents)->Expect.toEqual([])
    setup({...context, command: #dev})
    let (_, source) =
      scripts.contents->Array.find(((stage, _)) => stage == "page")->Option.getOrThrow
    t->expect(source->String.startsWith("import \""))->Expect.toBe(true)
    t->expect(source->String.endsWith("/navigation.js\";"))->Expect.toBe(true)
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
