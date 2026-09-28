module B = FrontmanBindings.ChromeLauncher

type launchedChrome = B.launchedChrome
type launchOptions = B.launchOptions

let getPort = B.getPort
@@live
let getPid = B.getPid

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

let killSafely = async (chrome: B.launchedChrome): unit => {
  try {
    await B.kill(chrome)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Console.error(
      `[chrome-launcher] Failed to kill Chrome (pid ${B.getPid(chrome)->Int.toString}): ${msg}`,
    )
  }
}
