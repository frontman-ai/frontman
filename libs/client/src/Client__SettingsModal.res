module Dialog = Client__UI__Dialog
module Input = Client__UI__Input
module Button = Client__UI__Button
module Icons = Client__UI__Icons
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

@val external confirm: string => bool = "confirm"

let requestSettingsOpenChange = (open_, hasUnsavedChanges, onOpenChange) =>
  switch (open_, hasUnsavedChanges) {
  | (false, true) =>
    switch confirm("You have unsaved changes. Discard them and close?") {
    | true => onOpenChange(false)
    | false => ()
    }
  | _ => onOpenChange(open_)
  }

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

let emptyCustomProviderDraft: Types.customProviderDraft = {
  id: None,
  name: "",
  baseUrl: "",
  apiKeyChange: Types.KeepCustomProviderApiKey,
  models: [],
  lockVersion: None,
}

let customProviderDraft = (provider: Types.customProvider): Types.customProviderDraft => {
  id: Some(provider.id),
  name: provider.name,
  baseUrl: provider.baseUrl,
  apiKeyChange: Types.KeepCustomProviderApiKey,
  models: provider.models,
  lockVersion: Some(provider.lockVersion),
}

module CustomProviderCard = {
  @react.component
  let make = (
    ~provider: option<Types.customProvider>,
    ~onClose: option<unit => unit>=?,
    ~onDirtyChange: bool => unit=_ => (),
  ) => {
    let (draft, setDraft) = React.useState(() =>
      provider->Option.map(customProviderDraft)->Option.getOr(emptyCustomProviderDraft)
    )
    let (newModelId, setNewModelId) = React.useState(() => "")
    let mutation = State.useSelector(State.Selectors.customProviderMutation)
    let controlsDisabled = mutation != Types.CustomProviderMutationIdle
    let initialDraft =
      provider->Option.map(customProviderDraft)->Option.getOr(emptyCustomProviderDraft)
    let hasChanges = draft != initialDraft
    let hasUnsavedChanges = hasChanges || newModelId->String.trim != ""
    let apiKeyInput = switch draft.apiKeyChange {
    | Types.ReplaceCustomProviderApiKey(key) => key
    | Types.KeepCustomProviderApiKey | Types.ClearCustomProviderApiKey => ""
    }

    React.useEffect1(() => {
      onDirtyChange(hasUnsavedChanges)
      Some(() => onDirtyChange(false))
    }, [hasUnsavedChanges])

    React.useEffect2(() => {
      switch (mutation, provider) {
      | (Types.CustomProviderMutationSucceeded(Types.SavingCustomProvider(Some(id))), Some(saved))
        if saved.id == id && Some(saved.lockVersion) != draft.lockVersion =>
        setDraft(_ => customProviderDraft(saved))
        State.Actions.acknowledgeCustomProviderMutation()
      | _ => ()
      }
      None
    }, (mutation, provider))

    let doSave = () =>
      State.Actions.saveCustomProvider(
        ~draft={
          ...draft,
          name: draft.name->String.trim,
          baseUrl: draft.baseUrl->String.trim,
        },
      )

    let addModel = () => {
      let trimmedModelId = String.trim(newModelId)

      switch (trimmedModelId, draft.models->Array.includes(trimmedModelId)) {
      | ("", _) | (_, true) => ()
      | (_, false) =>
        setDraft(current => {...current, models: current.models->Array.concat([trimmedModelId])})
        setNewModelId(_ => "")
      }
    }

    let matchingFailure = switch mutation {
    | Types.CustomProviderMutationFailed({operation: Types.SavingCustomProvider(id), error})
      if id == draft.id =>
      Some((Types.SavingCustomProvider(id), error))
    | Types.CustomProviderMutationFailed({operation: Types.DeletingCustomProvider(id), error})
      if Some(id) == draft.id =>
      Some((Types.DeletingCustomProvider(id), error))
    | _ => None
    }

    let errorMessage = switch matchingFailure {
    | Some((_, Types.CustomProviderValidationError(errors))) =>
      errors->Dict.valuesToArray->Array.flatMap(messages => messages)->Array.get(0)
    | Some((_, Types.CustomProviderNotFound)) => Some("Provider no longer exists")
    | Some((_, Types.CustomProviderNetworkError(message))) => Some(message)
    | Some((_, Types.CustomProviderConflict(_))) => Some("Provider changed elsewhere")
    | None => None
    }

    let confirmThen = (message, action) =>
      switch confirm(message) {
      | true => action()
      | false => ()
      }

    let failureActions = switch matchingFailure {
    | Some((Types.SavingCustomProvider(_), Types.CustomProviderConflict(current))) => [
        (
          "Load latest",
          () =>
            confirmThen("Discard unsaved changes and load latest provider?", () => {
              setDraft(_ => customProviderDraft(current))
              State.Actions.acknowledgeCustomProviderMutation()
            }),
        ),
        (
          "Overwrite latest",
          () =>
            confirmThen("Overwrite latest provider with unsaved changes?", () => {
              State.Actions.acknowledgeCustomProviderMutation()
              State.Actions.saveCustomProvider(
                ~draft={
                  ...draft,
                  lockVersion: Some(current.lockVersion),
                },
              )
            }),
        ),
      ]
    | Some((Types.DeletingCustomProvider(_), Types.CustomProviderConflict(current))) => [
        ("Cancel delete", State.Actions.acknowledgeCustomProviderMutation),
        (
          "Delete latest",
          () =>
            confirmThen("Delete latest provider?", () => {
              State.Actions.acknowledgeCustomProviderMutation()
              State.Actions.deleteCustomProvider(~id=current.id, ~lockVersion=current.lockVersion)
            }),
        ),
      ]
    | Some(_) => [("Dismiss", State.Actions.acknowledgeCustomProviderMutation)]
    | None => []
    }

    let hasApiKey = provider->Option.map(provider => provider.hasApiKey)->Option.getOr(false)

    <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-4">
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-zinc-100">
          {React.string(provider->Option.isNone ? "New provider" : draft.name)}
        </span>
        <div className="flex gap-2">
          {switch provider {
          | Some(provider) =>
            <Button
              variant={Button.Variant.Destructive}
              size={Button.Size.Sm}
              disabled=controlsDisabled
              onClick={_ =>
                confirmThen("Delete provider?", () =>
                  State.Actions.deleteCustomProvider(
                    ~id=provider.id,
                    ~lockVersion=provider.lockVersion,
                  )
                )}
            >
              {React.string("Delete")}
            </Button>
          | None => React.null
          }}
          <Button
            variant={Button.Variant.Ghost}
            size={Button.Size.Sm}
            disabled={controlsDisabled || (provider->Option.isSome && !hasUnsavedChanges)}
            onClick={_ =>
              switch provider {
              | Some(provider) => {
                  setDraft(_ => customProviderDraft(provider))
                  setNewModelId(_ => "")
                }
              | None => onClose->Option.forEach(close => close())
              }}
          >
            {React.string("Cancel")}
          </Button>
          <Button
            variant={Button.Variant.Secondary}
            size={Button.Size.Sm}
            onClick={_ => doSave()}
            disabled={controlsDisabled || !hasChanges}
          >
            {React.string(controlsDisabled ? "Saving..." : "Save")}
          </Button>
        </div>
      </div>
      <div className="mt-3 grid gap-2 sm:grid-cols-2">
        <Input
          type_="text"
          placeholder="Provider name"
          value={draft.name}
          onValueChange={(value, _) => setDraft(current => {...current, name: value})}
          disabled=controlsDisabled
        />
        <Input
          type_="text"
          placeholder="https://api.example.com/v1"
          value={draft.baseUrl}
          onValueChange={(value, _) => setDraft(current => {...current, baseUrl: value})}
          disabled=controlsDisabled
        />
        <div className="flex flex-col gap-2 sm:col-span-2 sm:flex-row">
          <Input
            type_="password"
            placeholder={hasApiKey ? "Key saved - enter replacement" : "Optional API key"}
            value={apiKeyInput}
            disabled=controlsDisabled
            className="min-w-0 flex-1"
            onValueChange={(value, _) => {
              setDraft(current => {
                ...current,
                apiKeyChange: switch value->String.trim {
                | "" => Types.KeepCustomProviderApiKey
                | key => Types.ReplaceCustomProviderApiKey(key)
                },
              })
            }}
          />
          {hasApiKey
            ? <Button
                variant={Button.Variant.Ghost}
                disabled=controlsDisabled
                onClick={_ => {
                  setDraft(current => {...current, apiKeyChange: Types.ClearCustomProviderApiKey})
                }}
              >
                {React.string("Remove key")}
              </Button>
            : React.null}
        </div>
      </div>
      {switch errorMessage {
      | Some(message) => <div className="mt-2 text-xs text-red-400"> {React.string(message)} </div>
      | None => React.null
      }}
      <div className="mt-3 border-t border-zinc-800 pt-3">
        <div className="space-y-2">
          {draft.models
          ->Array.mapWithIndex((model, modelIndex) =>
            <div key={modelIndex->Int.toString} className="flex gap-2">
              <Input
                type_="text"
                value=model
                disabled=controlsDisabled
                onValueChange={(value, _) =>
                  setDraft(current => {
                    ...current,
                    models: current.models->Array.mapWithIndex(
                      (currentModel, currentIndex) =>
                        switch currentIndex == modelIndex {
                        | true => value
                        | false => currentModel
                        },
                    ),
                  })}
              />
              <Button
                size={Button.Size.Sm}
                variant={Button.Variant.Link}
                disabled=controlsDisabled
                onClick={_ =>
                  setDraft(current => {
                    ...current,
                    models: current.models->Array.filter(currentModel => currentModel != model),
                  })}
              >
                {React.string("Remove")}
              </Button>
            </div>
          )
          ->React.array}
        </div>
        <div className="mt-2 flex gap-2">
          <Input
            type_="text"
            placeholder="Model ID"
            value={newModelId}
            onValueChange={(value, _) => setNewModelId(_ => value)}
            disabled=controlsDisabled
          />
          <Button
            size={Button.Size.Sm}
            variant={Button.Variant.Link}
            onClick={_ => addModel()}
            disabled={controlsDisabled ||
            newModelId->String.trim == "" ||
            draft.models->Array.includes(newModelId->String.trim)}
          >
            {React.string("Add")}
          </Button>
        </div>
      </div>
      {switch failureActions {
      | [] => React.null
      | actions =>
        <div className="flex gap-2">
          {actions
          ->Array.map(((label, action)) =>
            <Button
              key=label size={Button.Size.Sm} variant={Button.Variant.Ghost} onClick={_ => action()}
            >
              {React.string(label)}
            </Button>
          )
          ->React.array}
        </div>
      }}
    </div>
  }
}

module CustomProvidersSection = {
  @react.component
  let make = (~onDirtyChange: bool => unit=_ => ()) => {
    let customProviders = State.useSelector(State.Selectors.customProviders)
    let mutation = State.useSelector(State.Selectors.customProviderMutation)
    let (isDrafting, setIsDrafting) = React.useState(() => false)
    let (dirtyProviderIds, setDirtyProviderIds) = React.useState(() => [])
    let providers = customProviders->Option.getOr([])
    let showDraft =
      isDrafting ||
      switch mutation {
      | Types.CustomProviderMutationFailed({operation: Types.SavingCustomProvider(None), _}) => true
      | _ => false
      }

    let setProviderDirty = (providerId, isDirty) =>
      setDirtyProviderIds(current =>
        switch (isDirty, current->Array.includes(providerId)) {
        | (true, false) => current->Array.concat([providerId])
        | (false, true) => current->Array.filter(id => id != providerId)
        | _ => current
        }
      )

    React.useEffect1(() => {
      onDirtyChange(dirtyProviderIds->Array.length > 0)
      None
    }, [dirtyProviderIds])

    React.useEffect0(() => Some(() => onDirtyChange(false)))

    React.useEffect(() => {
      switch mutation {
      | Types.CustomProviderMutationSucceeded(Types.SavingCustomProvider(None)) =>
        setIsDrafting(_ => false)
        State.Actions.acknowledgeCustomProviderMutation()
      | Types.CustomProviderMutationSucceeded(Types.DeletingCustomProvider(_)) =>
        State.Actions.acknowledgeCustomProviderMutation()
      | _ => ()
      }
      None
    }, [mutation])

    <div className="space-y-4">
      <div className="text-sm text-zinc-400"> {React.string("Custom providers")} </div>
      {providers
      ->Array.map(provider =>
        <CustomProviderCard
          key={provider.id}
          provider={Some(provider)}
          onDirtyChange={isDirty => setProviderDirty(Some(provider.id), isDirty)}
        />
      )
      ->React.array}
      {switch showDraft {
      | true =>
        <CustomProviderCard
          provider=None
          onClose={() => setIsDrafting(_ => false)}
          onDirtyChange={isDirty => setProviderDirty(None, isDirty)}
        />
      | false => React.null
      }}
      <Button
        variant={Button.Variant.Secondary}
        onClick={_ => setIsDrafting(_ => true)}
        disabled={customProviders->Option.isNone ||
        showDraft ||
        mutation != Types.CustomProviderMutationIdle}
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
  let (customProvidersDirty, setCustomProvidersDirty) = React.useState(() => false)
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
      State.Actions.fetchCustomProviders()
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

  let hasUnsavedChanges =
    customProvidersDirty ||
    [openrouterKey, anthropicKey, fireworksKey, nvidiaKey, oauthCode]->Array.some(value =>
      value->String.trim != ""
    )

  <Dialog
    open_
    onOpenChange={(open_, _) => requestSettingsOpenChange(open_, hasUnsavedChanges, onOpenChange)}
  >
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
                </div>}
            <div className={activeTab == "providers" ? "mt-6" : "hidden"}>
              <CustomProvidersSection
                onDirtyChange={isDirty => setCustomProvidersDirty(_ => isDirty)}
              />
            </div>
          </div>
        </div>
      </div>
    </Dialog.Content>
  </Dialog>
}
