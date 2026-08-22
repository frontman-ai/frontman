module Dialog = Client__UI__Dialog
module Input = Client__UI__Input
module Button = Client__UI__Button
module Icons = Client__UI__Icons
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
  | Types.Loading => "Checking key status..."
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
  | Types.Loading => renderBadge(~label="Checking...", ~tone=Amber)
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
    <Button variant=Button.Variant.Secondary onClick={_ => onDisconnect()}>
      {React.string("Disconnect")}
    </Button>
  </div>
}

let emptyCustomEndpointDraft: Types.customEndpoint = {
  id: "",
  name: "",
  baseUrl: "",
  hasApiKey: false,
  models: [],
}

// Accepts http/https URLs (raw IP or localhost included); rejects anything
// without a scheme + host so a bad address is caught before save.
let isValidProviderUrl = (url: string): bool =>
  switch url->String.trim {
  | "" => false
  | trimmed =>
    try {
      let parsed = WebAPI.URL.make(~url=trimmed)
      switch parsed.protocol->String.toLowerCase {
      | "http:" | "https:" => parsed.hostname != ""
      | _ => false
      }
    } catch {
    | _ => false
    }
  }

module CustomEndpointCard = {
  @react.component
  let make = (
    ~endpoint: Types.customEndpoint,
    ~isDraft: bool,
    ~onDraftSaved: option<unit => unit>=?,
  ) => {
    let (name, setName) = React.useState(() => endpoint.name)
    let (baseUrl, setBaseUrl) = React.useState(() => endpoint.baseUrl)
    let (apiKeyInput, setApiKeyInput) = React.useState(() => "")
    let (newModelId, setNewModelId) = React.useState(() => "")
    let (busy, setBusy) = React.useState(() => false)
    let (error, setError) = React.useState(() => None)
    let (nameError, setNameError) = React.useState(() => None)
    let (urlError, setUrlError) = React.useState(() => None)
    let (confirmingDelete, setConfirmingDelete) = React.useState(() => false)

    let doSave = (~apiKey: option<string>) => {
      let trimmedName = String.trim(name)
      let trimmedUrl = String.trim(baseUrl)

      setError(_ => None)
      setNameError(_ => None)
      setUrlError(_ => None)

      switch (trimmedName, isValidProviderUrl(trimmedUrl)) {
      | ("", _) => setNameError(_ => Some("Provider name is required"))
      | (_, false) => setUrlError(_ => Some("Invalid URL"))
      | (_, true) =>
        setBusy(_ => true)
        State.Actions.saveCustomEndpoint(
          ~id=?isDraft ? None : Some(endpoint.id),
          ~name=trimmedName,
          ~baseUrl=trimmedUrl,
          ~apiKey?,
          ~onComplete=result => {
            setBusy(_ => false)
            switch result {
            | Ok(_) =>
              setApiKeyInput(_ => "")
              if isDraft {
                onDraftSaved->Option.forEach(callback => callback())
              }
            | Error(message) =>
              // Ecto's unique_constraint surfaces as "has already been taken".
              if message->String.includes("has already been taken") {
                setNameError(_ => Some("Provider name already used"))
              } else {
                setError(_ => Some(message))
              }
            }
          },
        )
      }
    }

    // Inline edits on persisted cards keep the stored key (apiKey: None).
    let saveIfChangedOnBlur = () =>
      if !isDraft {
        let trimmedName = String.trim(name)
        let trimmedUrl = String.trim(baseUrl)

        if (
          trimmedName != "" &&
          trimmedUrl != "" &&
          (trimmedName != endpoint.name || trimmedUrl != endpoint.baseUrl)
        ) {
          doSave(~apiKey=None)
        }
      }

    let addModel = () => {
      let trimmedModelId = String.trim(newModelId)

      if trimmedModelId != "" {
        State.Actions.addCustomEndpointModel(
          ~endpointId=endpoint.id,
          ~modelId=trimmedModelId,
          ~onComplete=result =>
            switch result {
            | Ok(_) => setNewModelId(_ => "")
            | Error(message) => setError(_ => Some(message))
            },
        )
      }
    }

    <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-zinc-100">
            {React.string(isDraft ? "New provider" : name == "" ? endpoint.name : name)}
          </span>
          {endpoint.hasApiKey
            ? renderBadge(~label="User key", ~tone=Blue)
            : renderBadge(~label="Not configured", ~tone=Zinc)}
        </div>
        {isDraft
          ? <Button
              variant={Button.Variant.Ghost}
              size={Button.Size.Sm}
              onClick={_ => onDraftSaved->Option.forEach(callback => callback())}
            >
              {React.string("Cancel")}
            </Button>
          : confirmingDelete
          ? <div className="flex items-center gap-3">
            <Button
              variant={Button.Variant.Destructive}
              size={Button.Size.Sm}
              onClick={_ =>
                State.Actions.deleteCustomEndpoint(~id=endpoint.id, ~onComplete=_ => ())}
            >
              {React.string("Confirm Delete?")}
            </Button>
            <Button
              variant={Button.Variant.Secondary}
              size={Button.Size.Sm}
              onClick={_ => setConfirmingDelete(_ => false)}
            >
              {React.string("Cancel")}
            </Button>
          </div>
          : <Button
              variant={Button.Variant.Destructive}
              size={Button.Size.Sm}
              onClick={_ => setConfirmingDelete(_ => true)}
            >
              {React.string("Delete")}
            </Button>}
      </div>
      <div className="mt-2 space-y-2">
        <div className="flex items-start gap-3">
          <div>
            <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Provider Name")} </div>
            <Input
              type_="text"
              placeholder=""
              value={name}
              onValueChange={(value, _) => setName(_ => value)}
              onBlur={_ => saveIfChangedOnBlur()}
              disabled={busy}
              className="w-56 min-w-0"
            />
            {switch nameError {
            | Some(msg) =>
              <div className="mt-1 text-[11px] text-red-400"> {React.string(msg)} </div>
            | None => React.null
            }}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Provider URL")} </div>
            <Input
              type_="text"
              placeholder="https://api.example.com/v1"
              value={baseUrl}
              onValueChange={(value, _) => setBaseUrl(_ => value)}
              onBlur={_ => saveIfChangedOnBlur()}
              disabled={busy}
              className="w-full min-w-0"
            />
            {switch urlError {
            | Some(msg) =>
              <div className="mt-1 text-[11px] text-red-400"> {React.string(msg)} </div>
            | None => React.null
            }}
          </div>
        </div>
        <div className="mt-2">
          <div className="text-[11px] text-zinc-500 mb-1"> {React.string("API Key")} </div>
          <div className="flex items-center gap-3">
            <Input
              type_="password"
              placeholder={endpoint.hasApiKey ? "Key saved - enter new key to replace" : "Optional"}
              value={apiKeyInput}
              onValueChange={(value, _) => setApiKeyInput(_ => value)}
              disabled={busy}
              className="flex-1 min-w-0"
            />
            <Button
              variant={Button.Variant.Secondary}
              onClick={_ => {
                let trimmedKey = String.trim(apiKeyInput)
                doSave(~apiKey=trimmedKey == "" ? None : Some(trimmedKey))
              }}
              disabled={busy}
            >
              {React.string(busy ? "Saving..." : "Save")}
            </Button>
          </div>
        </div>
        <div className="mt-1 text-[11px] text-zinc-600">
          {React.string("OpenAI compatible. Must support vision.")}
        </div>
      </div>
      {switch error {
      | Some(message) => <div className="mt-2 text-xs text-red-400"> {React.string(message)} </div>
      | None => React.null
      }}
      {if isDraft {
        React.null
      } else {
        <div className="mt-3 border-t border-zinc-800 pt-3">
          <div className="text-xs font-bold text-zinc-500"> {React.string("Models")} </div>
          <div className="mt-2 space-y-1">
            {endpoint.models
            ->Array.map(model =>
              <div key={model.id} className="flex items-center justify-between py-0.5">
                <div className="min-w-0 truncate">
                  {switch model.displayName {
                  | Some(displayName) =>
                    <span className="text-xs text-zinc-300"> {React.string(displayName)} </span>
                  | None => React.null
                  }}
                  <span className="text-xs text-zinc-100"> {React.string(model.modelId)} </span>
                </div>
                <button
                  type_="button"
                  className="text-xs text-zinc-400 transition-colors hover:text-zinc-200"
                  onClick={_ =>
                    State.Actions.removeCustomEndpointModel(
                      ~endpointId=endpoint.id,
                      ~modelId=model.modelId,
                      ~onComplete=_ => (),
                    )}
                >
                  {React.string("Remove")}
                </button>
              </div>
            )
            ->React.array}
            {if endpoint.models->Array.length == 0 {
              <div className="text-xs text-zinc-600"> {React.string("No models yet.")} </div>
            } else {
              React.null
            }}
            <div className="flex items-center gap-2 pt-1">
              <Input
                type_="text"
                placeholder="Model name (ie. gpt-4o-mini)"
                value={newModelId}
                onValueChange={(value, _) => setNewModelId(_ => value)}
                onKeyDown={e =>
                  switch ReactEvent.Keyboard.key(e) {
                  | "Enter" =>
                    ReactEvent.Keyboard.preventDefault(e)
                    addModel()
                  | _ => ()
                  }}
                className="flex-1 min-w-0 text-xs"
              />
              <Button
                size={Button.Size.Sm}
                variant={Button.Variant.Link}
                onClick={_ => addModel()}
                disabled={String.trim(newModelId) == ""}
              >
                {React.string("Add")}
              </Button>
            </div>
          </div>
        </div>
      }}
    </div>
  }
}

module CustomProvidersSection = {
  @react.component
  let make = () => {
    let customEndpoints = State.useSelector(State.Selectors.customEndpoints)
    let (draftSlots, setDraftSlots) = React.useState(() => [])
    let nextSlotId = React.useRef(0)

    let endpoints = customEndpoints->Option.getOr([])

    let removeDraftSlot = slotId =>
      setDraftSlots(slots => slots->Array.filter(slot => slot != slotId))

    <div className="space-y-4">
      <div className="text-sm text-zinc-400"> {React.string("Custom providers")} </div>
      {if customEndpoints->Option.isNone {
        <div
          className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4 text-xs text-zinc-500"
        >
          {React.string("Loading custom providers...")}
        </div>
      } else {
        React.null
      }}
      {endpoints
      ->Array.map(endpoint => <CustomEndpointCard key={endpoint.id} endpoint isDraft=false />)
      ->React.array}
      {draftSlots
      ->Array.map(slotId =>
        <CustomEndpointCard
          key={`draft-${slotId->Int.toString}`}
          endpoint=emptyCustomEndpointDraft
          isDraft=true
          onDraftSaved={() => removeDraftSlot(slotId)}
        />
      )
      ->React.array}
      <Button
        variant={Button.Variant.Secondary}
        onClick={_ => {
          let slotId = nextSlotId.current
          nextSlotId.current = slotId + 1
          setDraftSlots(slots => Array.concat(slots, [slotId]))
        }}
      >
        {React.string("Add Additional Provider")}
      </Button>
    </div>
  }
}

module APIKeyCard = {
  @react.component
  let make = (
    ~title,
    ~manageHref,
    ~emptyPlaceholder,
    ~description: option<string>=?,
    ~settings: Types.apiKeySettings,
    ~apiKey,
    ~setApiKey,
    ~save,
    ~reset,
  ) =>
    <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-zinc-100"> {React.string(title)} </span>
          {renderSourceBadge(settings.source)}
        </div>
        <a
          href=manageHref
          target="_blank"
          rel="noreferrer"
          className="text-xs text-zinc-400 hover:text-zinc-200"
        >
          {React.string("Manage keys")}
        </a>
      </div>
      {switch description {
      | Some(text) => <div className="mt-2 text-xs text-zinc-500"> {React.string(text)} </div>
      | None => React.null
      }}
      <div className="mt-3 flex items-center gap-3">
        <Input
          type_="password"
          placeholder={apiKeyPlaceholder(settings.source, emptyPlaceholder)}
          value={apiKey}
          onValueChange={(value, _) => {
            setApiKey(_ => value)
            reset()
          }}
          className="flex-1 min-w-0"
        />
        <Button
          variant=Button.Variant.Secondary
          onClick={_ => saveApiKey(~key=apiKey, ~save, ~clear=() => setApiKey(_ => ""))}
          disabled={settings.saveStatus == Types.Saving}
        >
          {React.string(saveButtonLabel(settings.saveStatus))}
        </Button>
      </div>
      {renderSaveStatus(settings.saveStatus)}
    </div>
}

@react.component
let make = (~open_: bool, ~onOpenChange: bool => unit, ~initialTab: option<string>=?) => {
  let {connectionState, beginLogout, _} = Client__FrontmanProvider.useFrontman()
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
  let (nvidiaKey, setNvidiaKey) = React.useState(() => "")
  let (oauthCode, setOauthCode) = React.useState(() => "")
  let userProfile = State.useSelector(State.Selectors.userProfile)
  let userEmail = userProfile->Option.map(p => p.email)

  let acpSession = State.useSelector(State.Selectors.acpSession)
  let keySettings = State.useSelector(State.Selectors.openrouterKeySettings)
  let anthropicKeySettings = State.useSelector(State.Selectors.anthropicKeySettings)
  let fireworksKeySettings = State.useSelector(State.Selectors.fireworksKeySettings)
  let nvidiaKeySettings = State.useSelector(State.Selectors.nvidiaKeySettings)
  let anthropicOAuthStatus = State.useSelector(State.Selectors.anthropicOAuthStatus)
  let openaiOAuthStatus = State.useSelector(State.Selectors.openaiOAuthStatus)

  React.useEffect2(() => {
    if open_ {
      State.Actions.fetchApiKeySettings()
      State.Actions.fetchCustomEndpoints()
      State.Actions.fetchAnthropicOAuthStatus()
      State.Actions.fetchOpenAIOAuthStatus()
      State.Actions.resetOpenRouterKeySaveStatus()
      State.Actions.resetAnthropicKeySaveStatus()
      State.Actions.resetFireworksKeySaveStatus()
      State.Actions.resetNvidiaKeySaveStatus()
      State.Actions.resetAnthropicOAuthError()
      State.Actions.resetOpenAIOAuthError()
      setOpenrouterKey(_ => "")
      setAnthropicKey(_ => "")
      setFireworksKey(_ => "")
      setNvidiaKey(_ => "")
      setOauthCode(_ => "")
    }
    None
  }, (open_, acpSession))

  let anthropicPlaceholder = apiKeyPlaceholder(
    anthropicKeySettings.source,
    "Enter Anthropic API key",
  )

  <Dialog open_ onOpenChange={(open_, _) => onOpenChange(open_)}>
    <Dialog.Content
      className="sm:max-w-none max-w-none h-[560px] w-[960px] p-0" showCloseButton={false}
    >
      <div className="flex h-full overflow-hidden">
        <Dialog.Title className="sr-only"> {React.string("Settings")} </Dialog.Title>
        <Dialog.Description className="sr-only">
          {React.string("Manage account, environment, provider connections, and API keys.")}
        </Dialog.Description>
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
            <Dialog.Close
              className="ring-offset-background focus:ring-ring data-[state=open]:bg-accent data-[state=open]:text-muted-foreground rounded-xs opacity-70 transition-opacity hover:opacity-100 focus:ring-2 focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
            >
              <Icons.Cross2Icon />
            </Dialog.Close>
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
                        {switch (connectionState, acpSession) {
                        | (LoggingOut, _) =>
                          <Button variant=Button.Variant.Outline size=Button.Size.Sm disabled=true>
                            <Client__UI__Spinner />
                            {React.string("Signing out...")}
                          </Button>
                        | (_, Types.AcpSessionActive({apiBaseUrl})) =>
                          <a
                            className={Button.buttonVariants(
                              ~variant=Button.Variant.Outline,
                              ~size=Button.Size.Sm,
                            )}
                            href={`${apiBaseUrl}/users/log-out?return_to=%2Fusers%2Fpopup-complete`}
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={_ => beginLogout()}
                          >
                            {React.string("Sign out")}
                          </a>
                        | (_, Types.NoAcpSession) => React.null
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
                        <Button
                          variant=Button.Variant.Secondary
                          onClick={_ => State.Actions.initiateAnthropicOAuth()}
                        >
                          {React.string("Connect with Anthropic")}
                        </Button>
                      | Types.FetchingStatus =>
                        <Button variant=Button.Variant.Secondary disabled={true}>
                          {React.string("Checking status...")}
                        </Button>
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
                            <Input
                              type_="text"
                              placeholder="Paste authorization code here"
                              value={oauthCode}
                              onValueChange={(value, _) => setOauthCode(_ => value)}
                              className="flex-1 min-w-0 font-mono text-xs"
                            />
                            <Button
                              variant=Button.Variant.Secondary
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
                            </Button>
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
                          <Button
                            variant=Button.Variant.Secondary
                            onClick={_ => {
                              State.Actions.resetAnthropicOAuthError()
                              State.Actions.initiateAnthropicOAuth()
                            }}
                          >
                            {React.string("Try again")}
                          </Button>
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
                          <Input
                            type_="password"
                            placeholder={anthropicPlaceholder}
                            value={anthropicKey}
                            onValueChange={(value, _) => {
                              setAnthropicKey(_ => value)
                              State.Actions.resetAnthropicKeySaveStatus()
                            }}
                            className="flex-1 min-w-0"
                          />
                          <Button
                            variant=Button.Variant.Secondary
                            onClick={_ =>
                              saveApiKey(
                                ~key=anthropicKey,
                                ~save=key => State.Actions.saveAnthropicKey(~key),
                                ~clear=() => setAnthropicKey(_ => ""),
                              )}
                            disabled={anthropicKeySettings.saveStatus == Types.Saving}
                          >
                            {React.string(saveButtonLabel(anthropicKeySettings.saveStatus))}
                          </Button>
                        </div>
                        {renderSaveStatus(anthropicKeySettings.saveStatus)}
                      </div>
                    }}
                  </div>

                  <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-100">
                          {React.string("OpenAI")}
                        </span>
                        {switch openaiOAuthStatus {
                        | Types.OpenAIConnected(_) => renderBadge(~label="Connected", ~tone=Emerald)
                        | Types.OpenAIFetchingStatus
                        | Types.OpenAIWaitingForCode
                        | Types.OpenAIShowingCode(_) =>
                          renderBadge(~label="Connecting...", ~tone=Amber)
                        | Types.OpenAIError(_) => renderBadge(~label="Error", ~tone=Red)
                        | Types.OpenAINotConnected =>
                          renderBadge(~label="Not connected", ~tone=Zinc)
                        }}
                      </div>
                    </div>

                    <div className="mt-2 text-xs text-zinc-500">
                      {React.string(
                        "Use your OpenAI account to power Frontman with OpenAI Codex models.",
                      )}
                    </div>

                    <div className="mt-3">
                      {switch openaiOAuthStatus {
                      | Types.OpenAINotConnected =>
                        <Button
                          variant=Button.Variant.Secondary
                          onClick={_ => State.Actions.initiateOpenAIOAuth()}
                        >
                          {React.string("Connect with OpenAI")}
                        </Button>
                      | Types.OpenAIFetchingStatus | Types.OpenAIWaitingForCode =>
                        <Button variant=Button.Variant.Secondary disabled={true}>
                          {React.string("Checking...")}
                        </Button>
                      | Types.OpenAIShowingCode({userCode, verificationUrl}) =>
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
                              {React.string("Authorize at OpenAI")}
                            </a>
                          </div>
                          <div className="flex items-center gap-2 text-xs text-zinc-500">
                            <span
                              className="inline-block size-3 animate-spin rounded-full border-2 border-zinc-600 border-t-zinc-300"
                            />
                            {React.string("Waiting for authorization...")}
                          </div>
                        </div>
                      | Types.OpenAIConnected({expiresAt}) =>
                        renderConnectedToken(~expiresAt, ~onDisconnect=() =>
                          State.Actions.disconnectOpenAIOAuth()
                        )
                      | Types.OpenAIError(msg) =>
                        <div className="space-y-2">
                          <div className="text-xs text-red-400"> {React.string(msg)} </div>
                          <Button
                            variant=Button.Variant.Secondary
                            onClick={_ => {
                              State.Actions.resetOpenAIOAuthError()
                              State.Actions.initiateOpenAIOAuth()
                            }}
                          >
                            {React.string("Try again")}
                          </Button>
                        </div>
                      }}
                    </div>
                  </div>

                  <div className="text-sm text-zinc-400">
                    {React.string("Bring your own key")}
                  </div>
                  <APIKeyCard
                    title="NVIDIA"
                    manageHref="https://build.nvidia.com/settings/api-keys"
                    emptyPlaceholder="Enter NVIDIA API key"
                    description="Use your NVIDIA API key to access NVIDIA-hosted models."
                    settings=nvidiaKeySettings
                    apiKey=nvidiaKey
                    setApiKey=setNvidiaKey
                    save={key => State.Actions.saveNvidiaKey(~key)}
                    reset={State.Actions.resetNvidiaKeySaveStatus}
                  />
                  <APIKeyCard
                    title="Fireworks AI"
                    manageHref="https://app.fireworks.ai/api-keys"
                    emptyPlaceholder="Enter Fireworks API key"
                    description="Use your Fireworks API key with Fire Pass to access Kimi K2.5 Turbo."
                    settings=fireworksKeySettings
                    apiKey=fireworksKey
                    setApiKey=setFireworksKey
                    save={key => State.Actions.saveFireworksKey(~key)}
                    reset={State.Actions.resetFireworksKeySaveStatus}
                  />
                  <APIKeyCard
                    title="OpenRouter"
                    manageHref="https://openrouter.ai/keys"
                    emptyPlaceholder="Enter OpenRouter API key"
                    settings=keySettings
                    apiKey=openrouterKey
                    setApiKey=setOpenrouterKey
                    save={key => State.Actions.saveOpenRouterKey(~key)}
                    reset={State.Actions.resetOpenRouterKeySaveStatus}
                  />
                  <CustomProvidersSection />
                </div>}
          </div>
        </div>
      </div>
    </Dialog.Content>
  </Dialog>
}
