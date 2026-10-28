/**
 * UpdateBanner - Shows a persistent, dismissible banner when a newer
 * integration version is available.
 */
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module RuntimeConfig = Client__RuntimeConfig

let wordpressUpdateCheckIntervalMs = 5 * 60 * 1000

type updateAction =
  | AgentUpdate(string)
  | WordPressUpdate(string)

let updateActionForTarget = (
  target: Client__State__Types.updateTarget,
  ~wordpressPluginsUrl: option<string>,
): updateAction =>
  switch target {
  | NpmPackage(npmPackage) => AgentUpdate(npmPackage)
  | WordPressPlugin =>
    WordPressUpdate(
      wordpressPluginsUrl->Option.getOrThrow(~message="WordPress plugins URL is required"),
    )
  }

let updateDisplayName = (target: Client__State__Types.updateTarget): string =>
  switch target {
  | NpmPackage(npmPackage) => npmPackage
  | WordPressPlugin => "Frontman for WordPress"
  }

@react.component
let make = () => {
  let updateInfo = Client__State.useSelector(Client__State.Selectors.updateInfo)
  let updateBannerDismissed = Client__State.useSelector(
    Client__State.Selectors.updateBannerDismissed,
  )
  let wordpressUpdates = Client__State.useSelector(Client__State.Selectors.wordpressUpdates)
  let wordpressUpdateUnsupported = wordpressUpdates == Unsupported
  let runtimeConfig = RuntimeConfig.read()
  let relay = Client__State.useSelector(Client__State.Selectors.getRelay)
  let apiBaseUrl = Client__State.useSelector(Client__State.Selectors.apiBaseUrl)
  let serverInfo = relay->Option.map(Relay.getServerInfo)

  React.useEffect3(() => {
    switch (serverInfo, apiBaseUrl, wordpressUpdateUnsupported) {
    | (Some(serverInfo), Some(apiBaseUrl), false) =>
      let target = RuntimeConfig.frameworkUpdateTarget(runtimeConfig.framework)
      let check = () =>
        Client__State.Actions.checkForUpdate(
          ~apiBaseUrl,
          ~installedVersion=serverInfo.version,
          ~target,
        )
      check()
      switch target {
      | NpmPackage(_) => None
      | WordPressPlugin =>
        let handleFocus = _ => check()
        let window = WebAPI.Window.current
        window->WebAPI.Window.addEventListener(Custom("focus"), handleFocus)
        let interval = WebAPI.Window.setInterval2(
          window,
          ~handler=check,
          ~timeout=wordpressUpdateCheckIntervalMs,
        )
        Some(
          () => {
            window->WebAPI.Window.removeEventListener(Custom("focus"), handleFocus)
            WebAPI.Window.clearInterval(window, interval)
          },
        )
      }
    | _ => None
    }
  }, (apiBaseUrl, serverInfo, wordpressUpdateUnsupported))

  let handleUpdateClick = () => {
    switch updateInfo {
    | Some({target, latestVersion, installedVersion}) =>
      switch updateActionForTarget(target, ~wordpressPluginsUrl=runtimeConfig.wordpressPluginsUrl) {
      | AgentUpdate(npmPackage) =>
        let projectRootHint = switch runtimeConfig.projectRoot {
        | Some(root) => ` The project root is ${root}.`
        | None => ""
        }
        let text =
          `Update ${npmPackage} from ${installedVersion} to ${latestVersion}.` ++
          projectRootHint ++
          ` Find which package.json contains ${npmPackage} as a dependency,` ++
          ` detect the package manager from the lock file` ++
          ` (yarn.lock, package-lock.json, pnpm-lock.yaml, or bun.lock),` ++ ` and run the appropriate update command from that package's directory.`
        let content = [Client__State.UserContentPart.Text({text: text})]
        Client__State.Actions.addUserMessage(~content)
        ->Promise.then(result => {
          switch result {
          | Ok() => Client__State.Actions.dismissUpdateBanner()
          | Error(error) => WebAPI.Window.current->WebAPI.Window.alert(~message=error)
          }
          Promise.resolve()
        })
        ->ignore
      | WordPressUpdate(_) => ()
      }
    | None => ()
    }
  }

  let handleDismiss = () => {
    Client__State.Actions.dismissUpdateBanner()
  }

  let updateBanner = switch (updateBannerDismissed, updateInfo) {
  | (false, Some({target, installedVersion, latestVersion})) =>
    <div
      className="flex items-start gap-3 mx-4 mt-3 px-4 py-3 bg-white/5 border border-white/10 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200"
    >
      <div className="flex-shrink-0 mt-0.5">
        <svg
          className="w-4 h-4 text-amber-400"
          ariaHidden=true
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
          />
        </svg>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-zinc-100">
          {React.string(switch target {
          | WordPressPlugin => "Plugin update available"
          | NpmPackage(_) => "Update available"
          })}
        </p>
        <p className="text-xs leading-relaxed text-zinc-400 mt-1 break-words">
          {React.string(`${updateDisplayName(target)} · `)}
          <span className="inline-block">
            {React.string(`${installedVersion} → ${latestVersion}`)}
          </span>
        </p>
        {switch updateActionForTarget(
          target,
          ~wordpressPluginsUrl=runtimeConfig.wordpressPluginsUrl,
        ) {
        | WordPressUpdate(_) =>
          <p className="text-xs leading-relaxed text-zinc-400 mt-2">
            {React.string("Update the plugin in WordPress, then reload Frontman.")}
          </p>
        | AgentUpdate(_) => React.null
        }}
        <div className="mt-3">
          {switch updateActionForTarget(
            target,
            ~wordpressPluginsUrl=runtimeConfig.wordpressPluginsUrl,
          ) {
          | AgentUpdate(_) =>
            <button
              type_="button"
              onClick={_ => handleUpdateClick()}
              className="inline-flex text-xs font-medium text-zinc-200 hover:text-white bg-white/5 hover:bg-white/10 border border-white/10 px-3 py-1.5 rounded transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-400"
            >
              {React.string("Update")}
            </button>
          | WordPressUpdate(href) =>
            <a
              href
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex text-xs font-medium text-zinc-200 hover:text-white bg-white/5 hover:bg-white/10 border border-white/10 px-3 py-1.5 rounded transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-400"
            >
              {React.string("Open WordPress admin")}
            </a>
          }}
        </div>
      </div>
      <button
        type_="button"
        onClick={_ => handleDismiss()}
        ariaLabel="Dismiss update notification"
        className="flex-shrink-0 p-1 -mr-1 -mt-0.5 rounded text-zinc-500 hover:text-zinc-200 hover:bg-white/5 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-400"
      >
        <svg
          className="w-3.5 h-3.5"
          ariaHidden=true
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor"
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  | _ => React.null
  }

  <>
    {switch wordpressUpdates {
    | Available({autoUpdateEnabled: false}) =>
      <div
        role="status"
        className="flex flex-wrap items-center gap-3 mx-4 mt-3 px-4 py-3 bg-amber-950/40 border border-amber-700/40 rounded-lg"
      >
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-amber-300">
            {React.string("Enable auto-updates for Frontman")}
          </p>
          <p className="text-xs text-amber-300/90 mt-1">
            {React.string(
              "Auto-updates are off in WordPress settings. We strongly recommend enabling them to receive the latest fixes and improvements. In Plugins, choose Enable auto-updates next to Frontman.",
            )}
          </p>
        </div>
        <a
          href={runtimeConfig.wordpressPluginsUrl->Option.getOrThrow(
            ~message="WordPress plugins URL is required",
          )}
          target="_blank"
          rel="noopener noreferrer"
          className="flex-shrink-0 text-xs font-medium text-amber-300 hover:text-amber-200 bg-amber-800/30 hover:bg-amber-800/50 px-2.5 py-1 rounded transition-colors"
        >
          {React.string("Open Plugins in wp-admin")}
        </a>
      </div>
    | Available({autoUpdateEnabled: true}) | NotChecked | Unsupported => React.null
    }}
    {updateBanner}
  </>
}
