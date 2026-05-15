module Button = Client__UI__Button
module Icons = Client__UI__Icons
module Badge = Client__UI__Badge
module Card = Client__UI__Card
module Item = Client__UI__Item
module Alert = Client__UI__Alert
module Spinner = Client__UI__Spinner
module Field = Client__UI__Field
module InputGroup = Client__UI__InputGroup
module Kbd = Client__UI__Kbd
module Separator = Client__UI__Separator
module State = Client__State
module Types = Client__State__Types

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
  | Types.Saving => <Field.Description> {React.string("Saving...")} </Field.Description>
  | Types.Saved => <Field.Description> {React.string("Saved")} </Field.Description>
  | Types.SaveError(msg) => <Field.Error> {React.string(msg)} </Field.Error>
  }

let saveButtonLabel = saveStatus =>
  switch saveStatus {
  | Types.Saving => "Saving..."
  | Types.Idle | Types.Saved | Types.SaveError(_) => "Save"
  }

let renderBadge = (~variant, ~label) => <Badge variant> {React.string(label)} </Badge>

let renderApiKeySourceBadge = source =>
  switch source {
  | Types.UserOverride => renderBadge(~variant=Badge.Variant.Blue, ~label="User key")
  | Types.FromEnv => renderBadge(~variant=Badge.Variant.Emerald, ~label="From environment")
  | Types.None => renderBadge(~variant=Badge.Variant.Zinc, ~label="Not configured")
  }

let renderAnthropicOAuthBadge = status =>
  switch status {
  | Types.Connected(_) => renderBadge(~variant=Badge.Variant.Emerald, ~label="Connected")
  | Types.FetchingStatus | Types.Authorizing(_) | Types.Exchanging =>
    renderBadge(~variant=Badge.Variant.Amber, ~label="Connecting...")
  | Types.Error(_) => renderBadge(~variant=Badge.Variant.Red, ~label="Error")
  | Types.NotConnected => renderBadge(~variant=Badge.Variant.Zinc, ~label="Not connected")
  }

let renderOpenAIOAuthBadge = status =>
  switch status {
  | Types.OpenAIConnected(_) => renderBadge(~variant=Badge.Variant.Emerald, ~label="Connected")
  | Types.OpenAIFetchingStatus | Types.OpenAIWaitingForCode | Types.OpenAIShowingCode(_) =>
    renderBadge(~variant=Badge.Variant.Amber, ~label="Connecting...")
  | Types.OpenAIError(_) => renderBadge(~variant=Badge.Variant.Red, ~label="Error")
  | Types.OpenAINotConnected => renderBadge(~variant=Badge.Variant.Zinc, ~label="Not connected")
  }

let renderExternalLink = (~href, ~label) =>
  <Button
    render={<a href target="_blank" rel="noopener noreferrer" />}
    variant=Button.Variant.Link
    size=Button.Size.Xs
  >
    {React.string(label)}
  </Button>

let renderOAuthLoadingButton = label =>
  <Button variant=Button.Variant.Secondary disabled={true}>
    <Spinner dataIcon=Spinner.InlineStart />
    {React.string(label)}
  </Button>

let renderOAuthError = (~message, ~retry) =>
  <Alert variant=Alert.Variant.Destructive>
    <Alert.Description> {React.string(message)} </Alert.Description>
    <Alert.Action>
      <Button variant=Button.Variant.Secondary size=Button.Size.Sm onClick={_ => retry()}>
        {React.string("Try again")}
      </Button>
    </Alert.Action>
  </Alert>

let renderProviderSummary = (
  ~name,
  ~badge,
  ~description=?,
  ~manageUrl=?,
  ~manageLabel="Manage keys",
) =>
  <Item>
    <Item.Content>
      <Item.Title>
        {React.string(name)}
        {badge}
      </Item.Title>
      {switch description {
      | Some(description) => <Item.Description> {React.string(description)} </Item.Description>
      | None => React.null
      }}
    </Item.Content>
    {switch manageUrl {
    | Some(href) => <Item.Actions> {renderExternalLink(~href, ~label=manageLabel)} </Item.Actions>
    | None => React.null
    }}
  </Item>

let renderApiKeySummary = (~badge, ~manageUrl) =>
  <Item size=Item.Size.Xs>
    <Item.Content>
      <Item.Title>
        {React.string("or use an API key")}
        {badge}
      </Item.Title>
    </Item.Content>
    <Item.Actions> {renderExternalLink(~href=manageUrl, ~label="Manage keys")} </Item.Actions>
  </Item>

let renderConnectedToken = (~expiresAt, ~onDisconnect) => {
  let expiryDate = Date.fromTime(expiresAt)
  let expiryStr = Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(expiryDate)
  <Field.Group>
    <Field.Description> {React.string(`Token expires: ${expiryStr}`)} </Field.Description>
    <Button variant=Button.Variant.Secondary onClick={_ => onDisconnect()}>
      {React.string("Disconnect")}
    </Button>
  </Field.Group>
}

let renderApiKeyForm = (
  ~apiKey,
  ~setApiKey,
  ~settings: Types.apiKeySettings,
  ~placeholder,
  ~save,
  ~reset,
) =>
  <Field>
    <InputGroup>
      <InputGroup.Input
        type_="password"
        placeholder
        value={apiKey}
        onValueChange={(value, _) => {
          setApiKey(_ => value)
          reset()
        }}
      />
      <InputGroup.Addon align=InputGroup.Align.InlineEnd>
        <InputGroup.Button
          variant=InputGroup.Variant.Secondary
          onClick={_ => saveApiKey(~key=apiKey, ~save, ~clear=() => setApiKey(_ => ""))}
          disabled={settings.saveStatus == Types.Saving}
        >
          {React.string(saveButtonLabel(settings.saveStatus))}
        </InputGroup.Button>
      </InputGroup.Addon>
    </InputGroup>
    {renderSaveStatus(settings.saveStatus)}
  </Field>

let renderApiKeyProviderCard = (
  ~name,
  ~description=?,
  ~manageUrl,
  ~badge,
  ~apiKey,
  ~setApiKey,
  ~settings: Types.apiKeySettings,
  ~placeholder,
  ~save,
  ~reset,
) =>
  <Card size=Card.Size.Sm>
    <Card.Header> {renderProviderSummary(~name, ~badge, ~description?, ~manageUrl)} </Card.Header>
    <Card.Content>
      {renderApiKeyForm(~apiKey, ~setApiKey, ~settings, ~placeholder, ~save, ~reset)}
    </Card.Content>
  </Card>

@react.component
let make = (~open_) => {
  let (openrouterKey, setOpenrouterKey) = React.useState(() => "")
  let (anthropicKey, setAnthropicKey) = React.useState(() => "")
  let (fireworksKey, setFireworksKey) = React.useState(() => "")
  let (nvidiaKey, setNvidiaKey) = React.useState(() => "")
  let (oauthCode, setOauthCode) = React.useState(() => "")

  let acpSession = State.useSelector(State.Selectors.acpSession)
  let keySettings = State.useSelector(State.Selectors.openrouterKeySettings)
  let anthropicKeySettings = State.useSelector(State.Selectors.anthropicKeySettings)
  let fireworksKeySettings = State.useSelector(State.Selectors.fireworksKeySettings)
  let nvidiaKeySettings = State.useSelector(State.Selectors.nvidiaKeySettings)
  let anthropicOAuthStatus = State.useSelector(State.Selectors.anthropicOAuthStatus)
  let openaiOAuthStatus = State.useSelector(State.Selectors.openaiOAuthStatus)

  React.useEffect2(() => {
    switch open_ {
    | true =>
      State.Actions.fetchApiKeySettings()
      State.Actions.fetchAnthropicApiKeySettings()
      State.Actions.fetchFireworksApiKeySettings()
      State.Actions.fetchNvidiaApiKeySettings()
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
    | false => ()
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
  let nvidiaPlaceholder = apiKeyPlaceholder(nvidiaKeySettings.source, "Enter NVIDIA API key")

  <div className="space-y-6">
    <Field.Set>
      <Field.Legend variant=Field.Variant.Label>
        {React.string("Connect your account")}
      </Field.Legend>
      <Card size=Card.Size.Sm>
        <Card.Header>
          {renderProviderSummary(
            ~name="Anthropic Claude Pro/Max",
            ~badge={renderAnthropicOAuthBadge(anthropicOAuthStatus)},
            ~description="Use your Claude Pro or Max subscription to power Frontman.",
            ~manageUrl="https://console.anthropic.com/settings/oauth",
            ~manageLabel="Manage connections",
          )}
        </Card.Header>
        <Card.Content>
          {switch anthropicOAuthStatus {
          | Types.NotConnected =>
            <Button
              variant=Button.Variant.Secondary onClick={_ => State.Actions.initiateAnthropicOAuth()}
            >
              {React.string("Connect with Anthropic")}
            </Button>
          | Types.FetchingStatus => renderOAuthLoadingButton("Checking status...")
          | Types.Authorizing({authorizeUrl, verifier}) =>
            <Field.Group>
              <Field.Description>
                {React.string("1. Click the button below to authorize with Anthropic")}
              </Field.Description>
              <Button render={<a href={authorizeUrl} target="_blank" rel="noopener noreferrer" />}>
                {React.string("Open Anthropic Authorization")}
                <Icons.OpenInNewWindowIcon className="size-4" />
              </Button>
              <Field.Description>
                {React.string("2. After authorizing, copy the code and paste it below")}
              </Field.Description>
              <InputGroup>
                <InputGroup.Input
                  type_="text"
                  placeholder="Paste authorization code here"
                  value={oauthCode}
                  onValueChange={(value, _) => setOauthCode(_ => value)}
                  className="font-mono text-xs"
                />
                <InputGroup.Addon align=InputGroup.Align.InlineEnd>
                  <InputGroup.Button
                    variant=InputGroup.Variant.Secondary
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
                  </InputGroup.Button>
                </InputGroup.Addon>
              </InputGroup>
              <Button
                variant=Button.Variant.Link
                size=Button.Size.Sm
                onClick={_ => State.Actions.cancelAnthropicOAuth()}
              >
                {React.string("Cancel")}
              </Button>
            </Field.Group>
          | Types.Exchanging => renderOAuthLoadingButton("Connecting...")
          | Types.Connected({expiresAt}) =>
            renderConnectedToken(~expiresAt, ~onDisconnect=() =>
              State.Actions.disconnectAnthropicOAuth()
            )
          | Types.Error(msg) =>
            renderOAuthError(~message=msg, ~retry=() => {
              State.Actions.resetAnthropicOAuthError()
              State.Actions.initiateAnthropicOAuth()
            })
          }}
        </Card.Content>

        {switch anthropicOAuthStatus {
        | Types.Authorizing(_) | Types.Exchanging => React.null
        | _ =>
          <>
            <Separator />
            <Card.Content>
              <Field.Group>
                {switch anthropicOAuthStatus {
                | Types.Connected(_) =>
                  <Field.Description>
                    {React.string("OAuth is connected and takes priority over API key.")}
                  </Field.Description>
                | _ => React.null
                }}
                {renderApiKeySummary(
                  ~badge={renderApiKeySourceBadge(anthropicKeySettings.source)},
                  ~manageUrl="https://console.anthropic.com/settings/keys",
                )}
                {renderApiKeyForm(
                  ~apiKey=anthropicKey,
                  ~setApiKey=setAnthropicKey,
                  ~settings=anthropicKeySettings,
                  ~placeholder=anthropicPlaceholder,
                  ~save=key => State.Actions.saveAnthropicKey(~key),
                  ~reset=() => State.Actions.resetAnthropicKeySaveStatus(),
                )}
              </Field.Group>
            </Card.Content>
          </>
        }}
      </Card>

      <Card size=Card.Size.Sm>
        <Card.Header>
          {renderProviderSummary(
            ~name="ChatGPT Pro/Plus",
            ~badge={renderOpenAIOAuthBadge(openaiOAuthStatus)},
            ~description="Use your ChatGPT Pro or Plus subscription to power Frontman with OpenAI Codex models.",
          )}
        </Card.Header>
        <Card.Content>
          {switch openaiOAuthStatus {
          | Types.OpenAINotConnected =>
            <Button
              variant=Button.Variant.Secondary onClick={_ => State.Actions.initiateOpenAIOAuth()}
            >
              {React.string("Connect with ChatGPT")}
            </Button>
          | Types.OpenAIFetchingStatus | Types.OpenAIWaitingForCode =>
            renderOAuthLoadingButton("Checking...")
          | Types.OpenAIShowingCode({userCode, verificationUrl}) =>
            <Field.Group>
              <Field.Description>
                {React.string("Enter this code at OpenAI to connect your account:")}
              </Field.Description>
              <div className="flex items-center gap-3">
                <Kbd className="h-9 px-4 font-mono text-lg tracking-widest">
                  {React.string(userCode)}
                </Kbd>
                <Button
                  render={<a href={verificationUrl} target="_blank" rel="noopener noreferrer" />}
                  variant=Button.Variant.Secondary
                  size=Button.Size.Sm
                >
                  {React.string("Open OpenAI")}
                </Button>
              </div>
              <Field.Description>
                <Spinner dataIcon=Spinner.InlineStart className="size-3 text-zinc-300" />
                {React.string("Waiting for authorization...")}
              </Field.Description>
            </Field.Group>
          | Types.OpenAIConnected({expiresAt}) =>
            renderConnectedToken(~expiresAt, ~onDisconnect=() =>
              State.Actions.disconnectOpenAIOAuth()
            )
          | Types.OpenAIError(msg) =>
            renderOAuthError(~message=msg, ~retry=() => {
              State.Actions.resetOpenAIOAuthError()
              State.Actions.initiateOpenAIOAuth()
            })
          }}
        </Card.Content>
      </Card>
    </Field.Set>

    <Field.Set>
      <Field.Legend variant=Field.Variant.Label>
        {React.string("Bring your own key")}
      </Field.Legend>
      {renderApiKeyProviderCard(
        ~name="NVIDIA",
        ~manageUrl="https://build.nvidia.com/settings/api-keys",
        ~badge={renderApiKeySourceBadge(nvidiaKeySettings.source)},
        ~apiKey=nvidiaKey,
        ~setApiKey=setNvidiaKey,
        ~settings=nvidiaKeySettings,
        ~placeholder=nvidiaPlaceholder,
        ~save=key => State.Actions.saveNvidiaKey(~key),
        ~reset=() => State.Actions.resetNvidiaKeySaveStatus(),
      )}
      {renderApiKeyProviderCard(
        ~name="Fireworks AI",
        ~description="Use your Fireworks API key with Fire Pass to access Kimi K2.5 Turbo.",
        ~manageUrl="https://app.fireworks.ai/api-keys",
        ~badge={renderApiKeySourceBadge(fireworksKeySettings.source)},
        ~apiKey=fireworksKey,
        ~setApiKey=setFireworksKey,
        ~settings=fireworksKeySettings,
        ~placeholder=fireworksPlaceholder,
        ~save=key => State.Actions.saveFireworksKey(~key),
        ~reset=() => State.Actions.resetFireworksKeySaveStatus(),
      )}
      {renderApiKeyProviderCard(
        ~name="OpenRouter",
        ~manageUrl="https://openrouter.ai/keys",
        ~badge={renderApiKeySourceBadge(keySettings.source)},
        ~apiKey=openrouterKey,
        ~setApiKey=setOpenrouterKey,
        ~settings=keySettings,
        ~placeholder,
        ~save=key => State.Actions.saveOpenRouterKey(~key),
        ~reset=() => State.Actions.resetOpenRouterKeySaveStatus(),
      )}
    </Field.Set>
  </div>
}
