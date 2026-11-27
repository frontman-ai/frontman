module State = Client__State

// Presentation only: connection approval, access changes and validation use the
// same actions and effects as regular Settings.
@react.component
let make = () => {
  let status = State.useSelector(state => state.wordPressConnectionStatus)
  let credentialWarning = State.useSelector(state => state.wordPressCredentialWarning)
  let profile = State.useSelector(State.Selectors.userProfile)
  let loginRecovery = State.useSelector(State.Selectors.wordPressLoginRecovery)
  let connectionState = State.useSelector(State.Selectors.getConnectionStatus)
  let config = Client__RuntimeConfig.read()
  let site = config.wordpressSettingsUrl->Option.map(url =>
    WebAPI.URL.make(~url, ~base=(WebAPI.Window.current->WebAPI.Window.location).href).host
  )
  <main className="assistant-setup">
    <section className="assistant-setup-card" ariaLabel="WordPress assistant connection">
      <Client__FrontmanLogo size=36 />
      <h1> {React.string("Connect your WordPress site")} </h1>
      <p className="assistant-setup-intro">
        {React.string("Give your AI assistant access to this site through Frontman.")}
      </p>
      <div className="assistant-setup-account">
        {site->Option.mapOr(React.null, site => <p> {React.string(site)} </p>)}
        {profile->Option.mapOr(React.null, profile =>
          <p> {React.string(profile.email)} </p>
        )}
      </div>
      <Client__WordPressLoginBanner />
      {switch (loginRecovery, connectionState) {
      | (None, Error(message)) =>
        <div role="alert" className="space-y-3 text-sm text-red-300">
          <p> {React.string(message)} </p>
          <button
            type_="button"
            className="underline underline-offset-4"
            onClick={_ => State.Actions.reloadAfterWordPressLogin()}>
            {React.string("Reload Frontman")}
          </button>
        </div>
      | (None, Disconnected | Connecting | LoggingOut) =>
        <p role="status" className="text-sm text-zinc-400">
          {React.string("Connecting to Frontman...")}
        </p>
      | (Some(_), _) | (None, Connected | SessionActive(_)) =>
        <Client__WordPressConnectionCard
          focused=true
          authenticationRequired={loginRecovery->Option.isSome}
          status
          credentialWarning
          onConnect=State.Actions.connectWordPress
          onCheck=State.Actions.fetchWordPressConnection
          onSetAccess=State.Actions.setWordPressAccess
          settingsUrl=config.wordpressSettingsUrl
        />
      }}
      <button className="assistant-setup-exit" onClick={_ => State.Actions.exitWordPressAssistantArrival()}>
        {React.string("Open Frontman editor instead")}
      </button>
    </section>
  </main>
}
