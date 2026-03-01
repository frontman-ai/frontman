// Chrome launcher wrapper built on top of FrontmanBindings.ChromeLauncher
//
// Provides lazy-loaded launch (avoids bundler static resolution issues)
// and safe kill with error logging.

module B = FrontmanBindings.ChromeLauncher

// Re-export types and accessors so consumers don't need to reach into bindings
type launchedChrome = B.launchedChrome
type launchOptions = B.launchOptions

let getPort = B.getPort
let getPid = B.getPid

// Launch Chrome and return a LaunchedChrome instance.
// Loaded lazily at runtime to avoid bundler static resolution issues.
let launch: B.launchOptions => promise<B.launchedChrome> = %raw(`
  options =>
    import("node:module")
      .then(({createRequire}) => {
        const req = createRequire(import.meta.url)
        try {
          const mod = req("chrome-launcher")
          return mod.launch(options)
        } catch (e) {
          if (e.code === "MODULE_NOT_FOUND") {
            throw new Error("chrome-launcher is not installed. Run: npm install chrome-launcher")
          }
          throw e
        }
      })
`)

// Kill Chrome, logging errors but not throwing (e.g. already exited)
let killSafely = async (chrome: B.launchedChrome): unit => {
  try {
    await B.kill(chrome)
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Console.error(`[chrome-launcher] Failed to kill Chrome (pid ${B.getPid(chrome)->Int.toString}): ${msg}`)
  }
}
