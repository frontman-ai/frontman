module Dialog = Bindings__UI__Dialog
module Input = Bindings__UI__Input
module Button = Bindings__UI__Button
module Icons = Bindings__RadixUI__Icons
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

@react.component
let make = (~open_: bool, ~onOpenChange: bool => unit) => {
  let runtimeConfig = RuntimeConfig.read()
  let framework = runtimeConfig.framework
  let (activeTab, setActiveTab) = React.useState(() => "general")
  let (openrouterKey, setOpenrouterKey) = React.useState(() => "")
  let (oauthCode, setOauthCode) = React.useState(() => "")
  let (userEmail, setUserEmail) = React.useState(() => None)

  // Get ACP session for apiBaseUrl
  let acpSession = State.useSelector(State.Selectors.acpSession)

  // Get API key settings from state
  let keySettings = State.useSelector(State.Selectors.openrouterKeySettings)

  // Get Anthropic OAuth status from state
  let anthropicOAuthStatus = State.useSelector(State.Selectors.anthropicOAuthStatus)

  // Get ChatGPT OAuth status from state
  let chatgptOAuthStatus = State.useSelector(State.Selectors.chatgptOAuthStatus)

  // Fetch API key settings and user info when modal opens (or when ACP session becomes active)
  React.useEffect2(() => {
    if open_ {
      State.Actions.fetchApiKeySettings()
      State.Actions.fetchAnthropicOAuthStatus()
      State.Actions.fetchChatGPTOAuthStatus()
      State.Actions.resetOpenRouterKeySaveStatus()
      State.Actions.resetAnthropicOAuthError()
      State.Actions.resetChatGPTOAuthError()
      setOpenrouterKey(_ => "")
      setOauthCode(_ => "")

      // Fetch user info for General tab
      switch acpSession {
      | Types.AcpSessionActive({apiBaseUrl}) =>
        let fetchUser = async () => {
          try {
            let response = await WebAPI.Global.fetch(
              `${apiBaseUrl}/api/user/me`,
              ~init={credentials: Include},
            )
            if response.ok {
              let json = await response->WebAPI.Response.json
              switch json
              ->JSON.Decode.object
              ->Option.flatMap(obj => obj->Dict.get("email"))
              ->Option.flatMap(JSON.Decode.string) {
              | Some(email) => setUserEmail(_ => Some(email))
              | None => ()
              }
            }
          } catch {
          | _ => ()
          }
        }
        fetchUser()->ignore
      | _ => ()
      }
    }
    None
  }, (open_, acpSession))

  // Determine status label and style based on save status
  let (statusLabel, statusClass) = switch keySettings.saveStatus {
  | Types.Idle => ("", "mt-2 text-xs text-zinc-400")
  | Types.Saving => ("Saving...", "mt-2 text-xs text-zinc-400")
  | Types.Saved => ("Saved", "mt-2 text-xs text-emerald-300")
  | Types.SaveError(msg) => (msg, "mt-2 text-xs text-red-400")
  }

  // Determine placeholder text based on key source
  let placeholder = switch keySettings.source {
  | Types.UserOverride => "Key saved - enter new key to replace"
  | Types.FromEnv => "Using environment key - enter key to override"
  | Types.None => "Enter OpenRouter API key"
  }

  let handleSave = () => {
    let trimmedKey = String.trim(openrouterKey)
    if trimmedKey == "" {
      // Don't save empty keys - this is handled locally since we don't want to dispatch
      ()
    } else {
      State.Actions.saveOpenRouterKey(~key=trimmedKey)
      setOpenrouterKey(_ => "")
    }
  }

  // Render the source badge
  let sourceBadge = switch keySettings.source {
  | Types.UserOverride =>
    <span
      className="rounded-full bg-blue-500/20 px-2 py-0.5 text-[11px] font-semibold text-blue-200">
      {React.string("User key")}
    </span>
  | Types.FromEnv =>
    <span
      className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[11px] font-semibold text-emerald-200">
      {React.string("From environment")}
    </span>
  | Types.None =>
    <span
      className="rounded-full bg-zinc-700/50 px-2 py-0.5 text-[11px] font-semibold text-zinc-400">
      {React.string("Not configured")}
    </span>
  }

  <Dialog.Dialog open_={open_} onOpenChange={onOpenChange}>
    <Dialog.DialogContent
      className="sm:max-w-none max-w-none h-[560px] w-[960px] p-0" showCloseButton={true}>
      <div className="flex h-full">
        <div className="w-56 border-r border-zinc-800 bg-zinc-950/60 px-4 py-5">
          <div className="text-lg font-semibold text-zinc-100"> {React.string("Settings")} </div>
          <div className="mt-1 text-xs text-zinc-500">
            {React.string(
              "Settings are stored in your browser. API keys are saved to your account.",
            )}
          </div>
          <div className="mt-6 flex flex-col gap-1">
            <button
              type_="button"
              className={activeTab == "general"
                ? "flex items-center gap-2 rounded-md bg-zinc-800 px-3 py-2 text-sm text-zinc-100"
                : "flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-400 hover:bg-zinc-900"}
              onClick={_ => setActiveTab(_ => "general")}>
              <Icons.CubeIcon className="size-4" />
              {React.string("General")}
            </button>
            <button
              type_="button"
              className={activeTab == "providers"
                ? "flex items-center gap-2 rounded-md bg-zinc-800 px-3 py-2 text-sm text-zinc-100"
                : "flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-400 hover:bg-zinc-900"}
              onClick={_ => setActiveTab(_ => "providers")}>
              <Icons.GlobeIcon className="size-4" />
              {React.string("Providers")}
            </button>
          </div>
        </div>

        <div className="flex-1 px-6 py-6 pr-12 overflow-y-auto">
          {activeTab == "general"
            ? <div className="space-y-6">
                // Account section
                <div>
                  <div className="text-sm font-medium text-zinc-400">
                    {React.string("Account")}
                  </div>
                  <div className="mt-2 rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div
                          className="flex size-8 items-center justify-center rounded-full bg-zinc-700 text-xs font-medium text-zinc-200">
                          {React.string(
                            switch userEmail {
                            | Some(email) =>
                              email->String.charAt(0)->String.toUpperCase
                            | None => "?"
                            },
                          )}
                        </div>
                        <div>
                          {switch userEmail {
                          | Some(email) =>
                            <div className="text-sm text-zinc-100"> {React.string(email)} </div>
                          | None =>
                            <div className="text-sm text-zinc-500"> {React.string("Loading...")} </div>
                          }}
                          <div className="text-xs text-zinc-500">
                            {React.string("Signed in via OAuth")}
                          </div>
                        </div>
                      </div>
                      {switch acpSession {
                      | Types.AcpSessionActive({apiBaseUrl}) =>
                        <Button.Button
                          variant=#outline
                          size=#sm
                          onClick={_ => {
                            // Navigate to server-side logout with return_to so user is redirected
                            // back here after re-authenticating
                            let encodeURIComponent: string => string = %raw(`encodeURIComponent`)
                            let currentUrl =
                              WebAPI.Global.window
                              ->WebAPI.Window.location
                              ->WebAPI.Location.href
                            let returnTo = encodeURIComponent(currentUrl)
                            WebAPI.Global.window
                            ->WebAPI.Window.location
                            ->WebAPI.Location.assign(
                              `${apiBaseUrl}/users/log-out?return_to=${returnTo}`,
                            )
                          }}>
                          {React.string("Sign out")}
                        </Button.Button>
                      | _ => React.null
                      }}
                    </div>
                  </div>
                </div>
                // Framework detection
                <div>
                  <div className="text-sm font-medium text-zinc-400">
                    {React.string("Environment")}
                  </div>
                  <div
                    className="mt-2 rounded-lg border border-emerald-900/60 bg-emerald-900/20 px-4 py-3 text-sm text-emerald-200">
                    {React.string(`Framework detected: ${framework}`)}
                  </div>
                </div>
              </div>
            : <div className="space-y-6">
                // Anthropic OAuth Section
                <div className="text-sm text-zinc-400"> {React.string("Connect your account")} </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-zinc-100">
                        {React.string("Anthropic Claude Pro/Max")}
                      </span>
                      {switch anthropicOAuthStatus {
                      | Types.Connected(_) =>
                        <span
                          className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[11px] font-semibold text-emerald-200">
                          {React.string("Connected")}
                        </span>
                      | Types.FetchingStatus | Types.Authorizing(_) | Types.Exchanging =>
                        <span
                          className="rounded-full bg-amber-500/20 px-2 py-0.5 text-[11px] font-semibold text-amber-200">
                          {React.string("Connecting...")}
                        </span>
                      | Types.Error(_) =>
                        <span
                          className="rounded-full bg-red-500/20 px-2 py-0.5 text-[11px] font-semibold text-red-200">
                          {React.string("Error")}
                        </span>
                      | Types.NotConnected =>
                        <span
                          className="rounded-full bg-zinc-700/50 px-2 py-0.5 text-[11px] font-semibold text-zinc-400">
                          {React.string("Not connected")}
                        </span>
                      }}
                    </div>
                    <a
                      href="https://console.anthropic.com/settings/oauth"
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-zinc-400 hover:text-zinc-200">
                      {React.string("Manage connections")}
                    </a>
                  </div>

                  <div className="mt-2 text-xs text-zinc-500">
                    {React.string("Use your Claude Pro or Max subscription to power Frontman.")}
                  </div>

                  <div className="mt-3">
                    {switch anthropicOAuthStatus {
                    | Types.NotConnected =>
                      <Button.Button
                        variant=#secondary
                        onClick={_ => State.Actions.initiateAnthropicOAuth()}>
                        {React.string("Connect with Anthropic")}
                      </Button.Button>
                    | Types.FetchingStatus =>
                      <Button.Button variant=#secondary disabled={true}>
                        {React.string("Checking status...")}
                      </Button.Button>
                    | Types.Authorizing({authorizeUrl, verifier}) =>
                      <div className="space-y-3">
                        <div className="text-xs text-zinc-400">
                          {React.string("1. Click the button below to authorize with Anthropic")}
                        </div>
                        <a
                          href={authorizeUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-2 rounded-md bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500">
                          {React.string("Open Anthropic Authorization")}
                          <Icons.OpenInNewWindowIcon className="size-4" />
                        </a>
                        <div className="text-xs text-zinc-400">
                          {React.string("2. After authorizing, copy the code and paste it below")}
                        </div>
                        <div className="flex items-center gap-3">
                          <Input.Input
                            type_=#text
                            placeholder="Paste authorization code here"
                            value={oauthCode}
                            onChange={e => {
                              let target = ReactEvent.Form.target(e)
                              setOauthCode(_ => target["value"])
                            }}
                            className="flex-1 min-w-0 font-mono text-xs"
                          />
                          <Button.Button
                            variant=#secondary
                            disabled={String.trim(oauthCode) == ""}
                            onClick={_ => {
                              State.Actions.exchangeAnthropicOAuthCode(
                                ~code=String.trim(oauthCode),
                                ~verifier,
                              )
                              setOauthCode(_ => "")
                            }}>
                            {React.string("Submit")}
                          </Button.Button>
                        </div>
                      </div>
                    | Types.Exchanging =>
                      <div className="flex items-center gap-2 text-sm text-zinc-400">
                        <span
                          className="inline-block size-4 animate-spin rounded-full border-2 border-zinc-600 border-t-zinc-300"
                        />
                        {React.string("Connecting...")}
                      </div>
                    | Types.Connected({expiresAt}) => {
                        let expiryDate = Date.fromTime(expiresAt)
                        let expiryStr = Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(expiryDate)
                        <div className="space-y-2">
                          <div className="text-xs text-zinc-500">
                            {React.string(`Token expires: ${expiryStr}`)}
                          </div>
                          <Button.Button
                            variant=#secondary
                            onClick={_ => State.Actions.disconnectAnthropicOAuth()}>
                            {React.string("Disconnect")}
                          </Button.Button>
                        </div>
                      }
                    | Types.Error(msg) =>
                      <div className="space-y-2">
                        <div className="text-xs text-red-400"> {React.string(msg)} </div>
                        <Button.Button
                          variant=#secondary
                          onClick={_ => {
                            State.Actions.resetAnthropicOAuthError()
                            State.Actions.initiateAnthropicOAuth()
                          }}>
                          {React.string("Try again")}
                        </Button.Button>
                      </div>
                    }}
                  </div>
                </div>

                // ChatGPT OAuth Section
                <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-zinc-100">
                        {React.string("ChatGPT Pro/Plus")}
                      </span>
                      {switch chatgptOAuthStatus {
                      | Types.ChatGPTConnected(_) =>
                        <span
                          className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[11px] font-semibold text-emerald-200">
                          {React.string("Connected")}
                        </span>
                      | Types.ChatGPTFetchingStatus | Types.ChatGPTWaitingForCode | Types.ChatGPTShowingCode(_) =>
                        <span
                          className="rounded-full bg-amber-500/20 px-2 py-0.5 text-[11px] font-semibold text-amber-200">
                          {React.string("Connecting...")}
                        </span>
                      | Types.ChatGPTError(_) =>
                        <span
                          className="rounded-full bg-red-500/20 px-2 py-0.5 text-[11px] font-semibold text-red-200">
                          {React.string("Error")}
                        </span>
                      | Types.ChatGPTNotConnected =>
                        <span
                          className="rounded-full bg-zinc-700/50 px-2 py-0.5 text-[11px] font-semibold text-zinc-400">
                          {React.string("Not connected")}
                        </span>
                      }}
                    </div>
                  </div>

                  <div className="mt-2 text-xs text-zinc-500">
                    {React.string("Use your ChatGPT Pro or Plus subscription to power Frontman with OpenAI Codex models.")}
                  </div>

                  <div className="mt-3">
                    {switch chatgptOAuthStatus {
                    | Types.ChatGPTNotConnected =>
                      <Button.Button
                        variant=#secondary
                        onClick={_ => State.Actions.initiateChatGPTOAuth()}>
                        {React.string("Connect with ChatGPT")}
                      </Button.Button>
                    | Types.ChatGPTFetchingStatus | Types.ChatGPTWaitingForCode =>
                      <Button.Button variant=#secondary disabled={true}>
                        {React.string("Checking...")}
                      </Button.Button>
                    | Types.ChatGPTShowingCode({userCode, verificationUrl}) =>
                      <div className="space-y-3">
                        <div className="text-xs text-zinc-400">
                          {React.string("Enter this code at OpenAI to connect your account:")}
                        </div>
                        <div className="flex items-center gap-3">
                          <code
                            className="rounded-md bg-zinc-800 px-4 py-2 font-mono text-lg font-bold tracking-widest text-zinc-100">
                            {React.string(userCode)}
                          </code>
                          <a
                            href={verificationUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="rounded-md bg-zinc-700 px-3 py-2 text-xs font-medium text-zinc-200 transition-colors hover:bg-zinc-600">
                            {React.string("Open OpenAI")}
                          </a>
                        </div>
                        <div className="flex items-center gap-2 text-xs text-zinc-500">
                          <span
                            className="inline-block size-3 animate-spin rounded-full border-2 border-zinc-600 border-t-zinc-300"
                          />
                          {React.string("Waiting for authorization...")}
                        </div>
                      </div>
                    | Types.ChatGPTConnected({expiresAt}) => {
                        let expiryDate = Date.fromTime(expiresAt)
                        let expiryStr = Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(expiryDate)
                        <div className="space-y-2">
                          <div className="text-xs text-zinc-500">
                            {React.string(`Token expires: ${expiryStr}`)}
                          </div>
                          <Button.Button
                            variant=#secondary
                            onClick={_ => State.Actions.disconnectChatGPTOAuth()}>
                            {React.string("Disconnect")}
                          </Button.Button>
                        </div>
                      }
                    | Types.ChatGPTError(msg) =>
                      <div className="space-y-2">
                        <div className="text-xs text-red-400"> {React.string(msg)} </div>
                        <Button.Button
                          variant=#secondary
                          onClick={_ => {
                            State.Actions.resetChatGPTOAuthError()
                            State.Actions.initiateChatGPTOAuth()
                          }}>
                          {React.string("Try again")}
                        </Button.Button>
                      </div>
                    }}
                  </div>
                </div>

                // OpenRouter API Key Section
                <div className="text-sm text-zinc-400"> {React.string("Bring your own key")} </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-zinc-100">
                        {React.string("OpenRouter")}
                      </span>
                      {sourceBadge}
                    </div>

                    <a
                      href="https://openrouter.ai/keys"
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-zinc-400 hover:text-zinc-200">
                      {React.string("Manage keys")}
                    </a>
                  </div>
                  <div className="mt-3 flex items-center gap-3">
                    <Input.Input
                      type_=#password
                      placeholder={placeholder}
                      value={openrouterKey}
                      onChange={e => {
                        let target = ReactEvent.Form.target(e)
                        setOpenrouterKey(_ => target["value"])
                        State.Actions.resetOpenRouterKeySaveStatus()
                      }}
                      className="flex-1 min-w-0"
                    />
                    <Button.Button
                      variant=#secondary
                      onClick={_ => handleSave()}
                      disabled={keySettings.saveStatus == Types.Saving}>
                      {React.string(keySettings.saveStatus == Types.Saving ? "Saving..." : "Save")}
                    </Button.Button>
                  </div>
                  {statusLabel != ""
                    ? <div className={statusClass}> {React.string(statusLabel)} </div>
                    : React.null}
                </div>
              </div>}
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
