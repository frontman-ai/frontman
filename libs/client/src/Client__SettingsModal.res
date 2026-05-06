module Dialog = FrontmanBindings.Bindings__UI__Dialog
module Input = FrontmanBindings.Bindings__UI__Input
module Button = FrontmanBindings.Bindings__UI__Button
module Icons = FrontmanBindings.Bindings__RadixUI__Icons
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

type badgeTone = Blue | Emerald | Amber | Red | Zinc

let badgeClass = tone =>
  switch tone {
  | Blue => "rounded-full bg-blue-500/20 px-2 py-0.5 text-[11px] font-semibold text-blue-200"
  | Emerald => "rounded-full bg-emerald-500/20 px-2 py-0.5 text-[11px] font-semibold text-emerald-200"
  | Amber => "rounded-full bg-amber-500/20 px-2 py-0.5 text-[11px] font-semibold text-amber-200"
  | Red => "rounded-full bg-red-500/20 px-2 py-0.5 text-[11px] font-semibold text-red-200"
  | Zinc => "rounded-full bg-zinc-700/50 px-2 py-0.5 text-[11px] font-semibold text-zinc-400"
  }

let renderBadge = (~label, ~tone) =>
  <span className={badgeClass(tone)}> {React.string(label)} </span>

let apiKeyPlaceholder = (source, emptyText) =>
  switch source {
  | Types.UserOverride => "Key saved - enter new key to replace"
  | Types.FromEnv => "Using environment key - enter key to override"
  | Types.None => emptyText
  }

let saveApiKey = (~key, ~save, ~clear) => {
  let trimmedKey = String.trim(key)
  switch trimmedKey {
  | "" => ()
  | key => {
      save(key)
      clear()
    }
  }
}

let renderSaveStatus = saveStatus =>
  switch saveStatus {
  | Types.Idle => React.null
  | Types.Saving => <div className="mt-2 text-xs text-zinc-400"> {React.string("Saving...")} </div>
  | Types.Saved => <div className="mt-2 text-xs text-emerald-300"> {React.string("Saved")} </div>
  | Types.SaveError(msg) => <div className="mt-2 text-xs text-red-400"> {React.string(msg)} </div>
  }

let saveButtonLabel = saveStatus =>
  switch saveStatus {
  | Types.Saving => "Saving..."
  | Types.Idle | Types.Saved | Types.SaveError(_) => "Save"
  }

let renderSourceBadge = (source: Types.apiKeySource) =>
  switch source {
  | Types.UserOverride => renderBadge(~label="User key", ~tone=Blue)
  | Types.FromEnv => renderBadge(~label="From environment", ~tone=Emerald)
  | Types.None => renderBadge(~label="Not configured", ~tone=Zinc)
  }

let tabButtonClass = isActive =>
  switch isActive {
  | true => "flex items-center gap-2 rounded-md bg-zinc-800 px-3 py-2 text-sm text-zinc-100"
  | false => "flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-400 hover:bg-zinc-900"
  }

let renderConnectedToken = (~expiresAt, ~onDisconnect) => {
  let expiryDate = Date.fromTime(expiresAt)
  let expiryStr = Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(expiryDate)
  <div className="space-y-2">
    <div className="text-xs text-zinc-500"> {React.string(`Token expires: ${expiryStr}`)} </div>
    <Button.Button variant=#secondary onClick={_ => onDisconnect()}>
      {React.string("Disconnect")}
    </Button.Button>
  </div>
}

@react.component
let make = (~open_: bool, ~onOpenChange: bool => unit, ~initialTab: option<string>=?) => {
  let runtimeConfig = RuntimeConfig.read()
  let frameworkDisplayName = RuntimeConfig.frameworkDisplayName(runtimeConfig.framework)
  let (activeTab, setActiveTab) = React.useState(() => "general")

  React.useEffect2(() => {
    switch (open_, initialTab) {
    | (true, Some(tab)) => setActiveTab(_ => tab)
    | _ => ()
    }
    None
  }, (open_, initialTab))
  let (openrouterKey, setOpenrouterKey) = React.useState(() => "")
  let (anthropicKey, setAnthropicKey) = React.useState(() => "")
  let (fireworksKey, setFireworksKey) = React.useState(() => "")
  let (oauthCode, setOauthCode) = React.useState(() => "")
  let userProfile = State.useSelector(State.Selectors.userProfile)
  let userEmail = userProfile->Option.map(p => p.email)

  let acpSession = State.useSelector(State.Selectors.acpSession)
  let keySettings = State.useSelector(State.Selectors.openrouterKeySettings)
  let anthropicKeySettings = State.useSelector(State.Selectors.anthropicKeySettings)
  let fireworksKeySettings = State.useSelector(State.Selectors.fireworksKeySettings)
  let anthropicOAuthStatus = State.useSelector(State.Selectors.anthropicOAuthStatus)
  let chatgptOAuthStatus = State.useSelector(State.Selectors.chatgptOAuthStatus)

  React.useEffect2(() => {
    if open_ {
      State.Actions.fetchApiKeySettings()
      State.Actions.fetchAnthropicApiKeySettings()
      State.Actions.fetchFireworksApiKeySettings()
      State.Actions.fetchAnthropicOAuthStatus()
      State.Actions.fetchChatGPTOAuthStatus()
      State.Actions.resetOpenRouterKeySaveStatus()
      State.Actions.resetAnthropicKeySaveStatus()
      State.Actions.resetFireworksKeySaveStatus()
      State.Actions.resetAnthropicOAuthError()
      State.Actions.resetChatGPTOAuthError()
      setOpenrouterKey(_ => "")
      setAnthropicKey(_ => "")
      setFireworksKey(_ => "")
      setOauthCode(_ => "")
    }
    None
  }, (open_, acpSession))

  let placeholder = apiKeyPlaceholder(keySettings.source, "Enter OpenRouter API key")
  let anthropicPlaceholder = apiKeyPlaceholder(
    anthropicKeySettings.source,
    "Enter Anthropic API key",
  )
  let fireworksPlaceholder = apiKeyPlaceholder(
    fireworksKeySettings.source,
    "Enter Fireworks API key",
  )

  <Dialog.Dialog open_={open_} onOpenChange={onOpenChange}>
    <Dialog.DialogContent
      className="sm:max-w-none max-w-none h-[560px] w-[960px] p-0" showCloseButton={false}
    >
      <div className="flex h-full overflow-hidden">
        <Dialog.DialogTitle className="sr-only"> {React.string("Settings")} </Dialog.DialogTitle>
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
              className={tabButtonClass(activeTab == "general")}
              onClick={_ => setActiveTab(_ => "general")}
            >
              <Icons.CubeIcon className="size-4" />
              {React.string("General")}
            </button>
            <button
              type_="button"
              className={tabButtonClass(activeTab == "providers")}
              onClick={_ => setActiveTab(_ => "providers")}
            >
              <Icons.GlobeIcon className="size-4" />
              {React.string("Providers")}
            </button>
          </div>
        </div>

        <div className="flex flex-1 flex-col min-h-0">
          <div className="flex justify-end px-4 pt-4 pb-2">
            <Dialog.DialogClose
              className="ring-offset-background focus:ring-ring data-[state=open]:bg-accent data-[state=open]:text-muted-foreground rounded-xs opacity-70 transition-opacity hover:opacity-100 focus:ring-2 focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
            >
              <Icons.Cross2Icon />
            </Dialog.DialogClose>
          </div>
          <div className="flex-1 overflow-y-auto px-6 pb-6 pr-6">
            {activeTab == "general"
              ? <div className="space-y-6">
                  <div>
                    <div className="text-sm font-medium text-zinc-400">
                      {React.string("Account")}
                    </div>
                    <div
                      className="mt-2 rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div
                            className="flex size-8 items-center justify-center rounded-full bg-zinc-700 text-xs font-medium text-zinc-200"
                          >
                            {React.string(
                              switch userEmail {
                              | Some(email) => email->String.charAt(0)->String.toUpperCase
                              | None => "?"
                              },
                            )}
                          </div>
                          <div>
                            {switch userEmail {
                            | Some(email) =>
                              <div className="text-sm text-zinc-100"> {React.string(email)} </div>
                            | None =>
                              <div className="text-sm text-zinc-500">
                                {React.string("Loading...")}
                              </div>
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
                              let currentUrl = Client__HostNavigation.currentUrl()
                              let returnTo = encodeURIComponent(currentUrl)
                              Client__HostNavigation.assign(
                                ~url=`${apiBaseUrl}/users/log-out?return_to=${returnTo}`,
                              )
                            }}
                          >
                            {React.string("Sign out")}
                          </Button.Button>
                        | _ => React.null
                        }}
                      </div>
                    </div>
                  </div>
                  <div>
                    <div className="text-sm font-medium text-zinc-400">
                      {React.string("Environment")}
                    </div>
                    <div
                      className="mt-2 rounded-lg border border-emerald-900/60 bg-emerald-900/20 px-4 py-3 text-sm text-emerald-200"
                    >
                      {React.string(`Framework detected: ${frameworkDisplayName}`)}
                    </div>
                  </div>
                </div>
              : <div className="space-y-6">
                  <div className="text-sm text-zinc-400">
                    {React.string("Connect your account")}
                  </div>
                  <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-100">
                          {React.string("Anthropic Claude Pro/Max")}
                        </span>
                        {switch anthropicOAuthStatus {
                        | Types.Connected(_) => renderBadge(~label="Connected", ~tone=Emerald)
                        | Types.FetchingStatus | Types.Authorizing(_) | Types.Exchanging =>
                          renderBadge(~label="Connecting...", ~tone=Amber)
                        | Types.Error(_) => renderBadge(~label="Error", ~tone=Red)
                        | Types.NotConnected => renderBadge(~label="Not connected", ~tone=Zinc)
                        }}
                      </div>
                      <a
                        href="https://console.anthropic.com/settings/oauth"
                        target="_blank"
                        rel="noreferrer"
                        className="text-xs text-zinc-400 hover:text-zinc-200"
                      >
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
                          variant=#secondary onClick={_ => State.Actions.initiateAnthropicOAuth()}
                        >
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
                            className="inline-flex items-center gap-2 rounded-md bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
                          >
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
                              }}
                            >
                              {React.string("Submit")}
                            </Button.Button>
                          </div>
                          <button
                            type_="button"
                            className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors"
                            onClick={_ => State.Actions.cancelAnthropicOAuth()}
                          >
                            {React.string("Cancel")}
                          </button>
                        </div>
                      | Types.Exchanging =>
                        <div className="flex items-center gap-2 text-sm text-zinc-400">
                          <span
                            className="inline-block size-4 animate-spin rounded-full border-2 border-zinc-600 border-t-zinc-300"
                          />
                          {React.string("Connecting...")}
                        </div>
                      | Types.Connected({expiresAt}) =>
                        renderConnectedToken(~expiresAt, ~onDisconnect=() =>
                          State.Actions.disconnectAnthropicOAuth()
                        )
                      | Types.Error(msg) =>
                        <div className="space-y-2">
                          <div className="text-xs text-red-400"> {React.string(msg)} </div>
                          <Button.Button
                            variant=#secondary
                            onClick={_ => {
                              State.Actions.resetAnthropicOAuthError()
                              State.Actions.initiateAnthropicOAuth()
                            }}
                          >
                            {React.string("Try again")}
                          </Button.Button>
                        </div>
                      }}
                    </div>

                    {switch anthropicOAuthStatus {
                    | Types.Authorizing(_) | Types.Exchanging => React.null
                    | _ =>
                      <div className="mt-4 border-t border-zinc-800 pt-4">
                        {switch anthropicOAuthStatus {
                        | Types.Connected(_) =>
                          <div className="text-xs text-zinc-500">
                            {React.string("OAuth is connected and takes priority over API key.")}
                          </div>
                        | _ => React.null
                        }}
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <span className="text-xs text-zinc-400">
                              {React.string("or use an API key")}
                            </span>
                            {renderSourceBadge(anthropicKeySettings.source)}
                          </div>
                          <a
                            href="https://console.anthropic.com/settings/keys"
                            target="_blank"
                            rel="noreferrer"
                            className="text-xs text-zinc-400 hover:text-zinc-200"
                          >
                            {React.string("Manage keys")}
                          </a>
                        </div>
                        <div className="mt-2 flex items-center gap-3">
                          <Input.Input
                            type_=#password
                            placeholder={anthropicPlaceholder}
                            value={anthropicKey}
                            onChange={e => {
                              let target = ReactEvent.Form.target(e)
                              setAnthropicKey(_ => target["value"])
                              State.Actions.resetAnthropicKeySaveStatus()
                            }}
                            className="flex-1 min-w-0"
                          />
                          <Button.Button
                            variant=#secondary
                            onClick={_ =>
                              saveApiKey(
                                ~key=anthropicKey,
                                ~save=key => State.Actions.saveAnthropicKey(~key),
                                ~clear=() => setAnthropicKey(_ => ""),
                              )}
                            disabled={anthropicKeySettings.saveStatus == Types.Saving}
                          >
                            {React.string(saveButtonLabel(anthropicKeySettings.saveStatus))}
                          </Button.Button>
                        </div>
                        {renderSaveStatus(anthropicKeySettings.saveStatus)}
                      </div>
                    }}
                  </div>

                  <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-100">
                          {React.string("ChatGPT Pro/Plus")}
                        </span>
                        {switch chatgptOAuthStatus {
                        | Types.ChatGPTConnected(_) =>
                          renderBadge(~label="Connected", ~tone=Emerald)
                        | Types.ChatGPTFetchingStatus
                        | Types.ChatGPTWaitingForCode
                        | Types.ChatGPTShowingCode(_) =>
                          renderBadge(~label="Connecting...", ~tone=Amber)
                        | Types.ChatGPTError(_) => renderBadge(~label="Error", ~tone=Red)
                        | Types.ChatGPTNotConnected =>
                          renderBadge(~label="Not connected", ~tone=Zinc)
                        }}
                      </div>
                    </div>

                    <div className="mt-2 text-xs text-zinc-500">
                      {React.string(
                        "Use your ChatGPT Pro or Plus subscription to power Frontman with OpenAI Codex models.",
                      )}
                    </div>

                    <div className="mt-3">
                      {switch chatgptOAuthStatus {
                      | Types.ChatGPTNotConnected =>
                        <Button.Button
                          variant=#secondary onClick={_ => State.Actions.initiateChatGPTOAuth()}
                        >
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
                              className="rounded-md bg-zinc-800 px-4 py-2 font-mono text-lg font-bold tracking-widest text-zinc-100"
                            >
                              {React.string(userCode)}
                            </code>
                            <a
                              href={verificationUrl}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="rounded-md bg-zinc-700 px-3 py-2 text-xs font-medium text-zinc-200 transition-colors hover:bg-zinc-600"
                            >
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
                      | Types.ChatGPTConnected({expiresAt}) =>
                        renderConnectedToken(~expiresAt, ~onDisconnect=() =>
                          State.Actions.disconnectChatGPTOAuth()
                        )
                      | Types.ChatGPTError(msg) =>
                        <div className="space-y-2">
                          <div className="text-xs text-red-400"> {React.string(msg)} </div>
                          <Button.Button
                            variant=#secondary
                            onClick={_ => {
                              State.Actions.resetChatGPTOAuthError()
                              State.Actions.initiateChatGPTOAuth()
                            }}
                          >
                            {React.string("Try again")}
                          </Button.Button>
                        </div>
                      }}
                    </div>
                  </div>

                  <div className="text-sm text-zinc-400">
                    {React.string("Bring your own key")}
                  </div>
                  <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-100">
                          {React.string("Fireworks AI")}
                        </span>
                        {renderSourceBadge(fireworksKeySettings.source)}
                      </div>

                      <a
                        href="https://app.fireworks.ai/api-keys"
                        target="_blank"
                        rel="noreferrer"
                        className="text-xs text-zinc-400 hover:text-zinc-200"
                      >
                        {React.string("Manage keys")}
                      </a>
                    </div>
                    <div className="mt-2 text-xs text-zinc-500">
                      {React.string(
                        "Use your Fireworks API key with Fire Pass to access Kimi K2.5 Turbo.",
                      )}
                    </div>
                    <div className="mt-3 flex items-center gap-3">
                      <Input.Input
                        type_=#password
                        placeholder={fireworksPlaceholder}
                        value={fireworksKey}
                        onChange={e => {
                          let target = ReactEvent.Form.target(e)
                          setFireworksKey(_ => target["value"])
                          State.Actions.resetFireworksKeySaveStatus()
                        }}
                        className="flex-1 min-w-0"
                      />
                      <Button.Button
                        variant=#secondary
                        onClick={_ =>
                          saveApiKey(
                            ~key=fireworksKey,
                            ~save=key => State.Actions.saveFireworksKey(~key),
                            ~clear=() => setFireworksKey(_ => ""),
                          )}
                        disabled={fireworksKeySettings.saveStatus == Types.Saving}
                      >
                        {React.string(saveButtonLabel(fireworksKeySettings.saveStatus))}
                      </Button.Button>
                    </div>
                    {renderSaveStatus(fireworksKeySettings.saveStatus)}
                  </div>
                  <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-100">
                          {React.string("OpenRouter")}
                        </span>
                        {renderSourceBadge(keySettings.source)}
                      </div>

                      <a
                        href="https://openrouter.ai/keys"
                        target="_blank"
                        rel="noreferrer"
                        className="text-xs text-zinc-400 hover:text-zinc-200"
                      >
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
                        onClick={_ =>
                          saveApiKey(
                            ~key=openrouterKey,
                            ~save=key => State.Actions.saveOpenRouterKey(~key),
                            ~clear=() => setOpenrouterKey(_ => ""),
                          )}
                        disabled={keySettings.saveStatus == Types.Saving}
                      >
                        {React.string(saveButtonLabel(keySettings.saveStatus))}
                      </Button.Button>
                    </div>
                    {renderSaveStatus(keySettings.saveStatus)}
                  </div>
                </div>}
          </div>
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
