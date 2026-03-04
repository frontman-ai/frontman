/**
 * UpdateBanner - Shows a persistent, dismissible banner when a newer
 * integration package version is available on npm.
 *
 * Reads the relay's serverInfo for the installed version, maps the
 * framework to the npm package name, and fetches latest versions from
 * the Phoenix server endpoint.  The "Update" button sends a prompt
 * to the LLM asking it to perform the upgrade.
 */

module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module RuntimeConfig = Client__RuntimeConfig

@react.component
let make = () => {
  let updateInfo = Client__State.useSelector(Client__State.Selectors.updateInfo)
  let updateCheckStatus = Client__State.useSelector(Client__State.Selectors.updateCheckStatus)
  let updateBannerDismissed = Client__State.useSelector(
    Client__State.Selectors.updateBannerDismissed,
  )
  let hasActiveACPSession = Client__State.useSelector(Client__State.Selectors.hasActiveACPSession)
  let {relay, session, createSession} = Client__FrontmanProvider.useFrontman()

  // Trigger the version check once relay is connected AND ACP session is active.
  // The reducer guards against duplicate dispatches via updateCheckStatus.
  React.useEffect3(() => {
    switch (updateCheckStatus, relay, hasActiveACPSession) {
    | (UpdateNotChecked, Some(relayInstance), true) =>
      switch Relay.getState(relayInstance) {
      | Connected({serverInfo}) =>
        let runtimeConfig = RuntimeConfig.read()
        let npmPackage = RuntimeConfig.frameworkToNpmPackage(runtimeConfig.framework)
        Client__State.Actions.checkForUpdate(
          ~installedVersion=serverInfo.version,
          ~npmPackage,
        )
      | _ => ()
      }
    | _ => ()
    }
    None
  }, (updateCheckStatus, relay, hasActiveACPSession))

  let handleUpdateClick = () => {
    switch updateInfo {
    | Some({npmPackage, latestVersion, installedVersion}) =>
      let runtimeConfig = RuntimeConfig.read()
      let projectRootHint = switch runtimeConfig.projectRoot {
      | Some(root) => ` The project root is ${root}.`
      | None => ""
      }
      let text =
        `Update ${npmPackage} from ${installedVersion} to ${latestVersion}.` ++
        projectRootHint ++
        ` Find which package.json contains ${npmPackage} as a dependency,` ++
        ` detect the package manager from the lock file` ++
        ` (yarn.lock, package-lock.json, pnpm-lock.yaml, or bun.lock),` ++
        ` and run the appropriate update command from that package's directory.`
      let content = [Client__State.UserContentPart.Text({text: text})]
      let sendMessage = (sessionId: string) => {
        Client__State.Actions.addUserMessage(~sessionId, ~content)
      }
      switch session {
      | Some(sess) =>
        sendMessage(sess.sessionId)
        Client__State.Actions.dismissUpdateBanner()
      | None =>
        createSession(~onComplete=result => {
          switch result {
          | Ok(sessionId) =>
            sendMessage(sessionId)
            Client__State.Actions.dismissUpdateBanner()
          | Error(_) => ()
          }
        })
      }
    | None => ()
    }
  }

  let handleDismiss = () => {
    Client__State.Actions.dismissUpdateBanner()
  }

  switch (updateBannerDismissed, updateInfo) {
  | (false, Some({npmPackage, installedVersion, latestVersion})) =>
    <div
      className="flex items-center gap-3 mx-4 mt-3 px-4 py-3 bg-amber-950/40 border border-amber-700/40 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200">
      // Update icon
      <div className="flex-shrink-0">
        <svg
          className="w-4 h-4 text-amber-400"
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
          />
        </svg>
      </div>
      // Banner content
      <div className="flex-1 min-w-0">
        <p className="text-xs text-amber-300/90">
          {React.string(`${npmPackage} ${installedVersion} `)}
          <span className="text-amber-500/70"> {React.string(`\u2192`)} </span>
          {React.string(` ${latestVersion}`)}
        </p>
      </div>
      // Update button
      <button
        type_="button"
        onClick={_ => handleUpdateClick()}
        className="flex-shrink-0 text-xs font-medium text-amber-300 hover:text-amber-200 bg-amber-800/30 hover:bg-amber-800/50 px-2.5 py-1 rounded transition-colors">
        {React.string("Update")}
      </button>
      // Dismiss button
      <button
        type_="button"
        onClick={_ => handleDismiss()}
        className="flex-shrink-0 text-amber-500/50 hover:text-amber-400/80 transition-colors">
        <svg
          className="w-3.5 h-3.5"
          fill="none"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  | _ => React.null
  }
}
