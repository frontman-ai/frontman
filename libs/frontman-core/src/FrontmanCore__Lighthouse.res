// Lighthouse runner built on top of FrontmanBindings.Lighthouse
//
// Provides lazy-loaded run function that avoids bundler static resolution issues.

module B = FrontmanBindings.Lighthouse

// Run lighthouse on a URL.
// Loaded lazily at runtime to avoid bundler static resolution issues.
let run: (string, B.flags) => promise<Nullable.t<B.runnerResult>> = %raw(`
  (url, flags) =>
    import("node:module")
      .then(({createRequire}) => {
        const req = createRequire(import.meta.url)
        try {
          const mod = req("lighthouse")
          const lighthouse = mod.default ?? mod
          return lighthouse(url, flags)
        } catch (e) {
          if (e.code === "MODULE_NOT_FOUND") {
            throw new Error("lighthouse is not installed. Run: npm install lighthouse")
          }
          throw e
        }
      })
`)
