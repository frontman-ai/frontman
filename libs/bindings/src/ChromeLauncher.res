// Bindings for chrome-launcher package
// https://github.com/nickclaw/chrome-launcher

// Opaque type for the launched Chrome instance
type launchedChrome

// Chrome launch options
type launchOptions = {
  chromeFlags?: array<string>,
  chromePath?: string,
  port?: int,
  handleSIGINT?: bool,
  ignoreDefaultFlags?: bool,
}

// Launch Chrome and return a LaunchedChrome instance
// Loaded lazily at runtime to avoid bundler static resolution issues.
let launch: launchOptions => promise<launchedChrome> = %raw(`
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

// Get the debugging port from a launched Chrome instance
@get external getPort: launchedChrome => int = "port"

// Get the process ID
@get external getPid: launchedChrome => int = "pid"

// Kill the Chrome process
@send external kill: launchedChrome => promise<unit> = "kill"
