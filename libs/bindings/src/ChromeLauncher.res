// Bindings for chrome-launcher package
// https://github.com/GoogleChrome/chrome-launcher
//
// Pure bindings — types and externals only.
// For the high-level launch/kill API, see FrontmanCore.ChromeLauncher.

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

// Get the debugging port from a launched Chrome instance
@get external getPort: launchedChrome => int = "port"

// Get the process ID
@get external getPid: launchedChrome => int = "pid"

// Kill the Chrome process
@send external kill: launchedChrome => promise<unit> = "kill"
