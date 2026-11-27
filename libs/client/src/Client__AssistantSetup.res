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
  <main className="grid min-h-dvh place-items-center bg-[#020617] px-5 py-8 text-[#ededee]">
    <section
      className="assistant-setup-card w-full max-w-[560px] rounded-3xl bg-[#18181b] p-8 [&_[data-slot=button]]:w-full [&_[data-slot=button]]:min-h-14 [&_[data-slot=button]]:rounded-full [&_[data-slot=button]]:px-6 [&_[data-slot=button]]:py-3 [&_[data-slot=button]]:text-base [&_[data-slot=button]]:font-medium [&_[data-slot=button]]:bg-[#e4dbff] [&_[data-slot=button]]:text-[#201532]"
      ariaLabel="WordPress assistant connection">
      <Client__FrontmanLogo size=36 />
      <h1 className="mt-6 mb-3 text-3xl leading-tight font-medium tracking-tight">
        {React.string("Connect your WordPress site")}
      </h1>
      <p className="mb-5 text-sm leading-[1.6] text-[#aaa9b0]">
        {React.string("Give your AI assistant access to this site through Frontman.")}
      </p>
      <div className="mb-5 text-sm leading-[1.6] text-[#d1c6fa] [overflow-wrap:anywhere]">
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
      <button
        className="mt-7 cursor-pointer text-[13px] text-[#aaa9b0] underline underline-offset-4 hover:text-[#ededee]"
        onClick={_ => State.Actions.exitWordPressAssistantArrival()}>
        {React.string("Open Frontman editor instead")}
      </button>
    </section>
  </main>
}
