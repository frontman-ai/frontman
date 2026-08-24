type launchedChrome

type launchOptions = {
  chromeFlags?: array<string>,
  chromePath?: string,
  port?: int,
  handleSIGINT?: bool,
  ignoreDefaultFlags?: bool,
}

@get external getPort: launchedChrome => int = "port"

@get external getPid: launchedChrome => int = "pid"

@send external kill: launchedChrome => promise<unit> = "kill"
