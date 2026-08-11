module B = FrontmanBindings.Lighthouse

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
