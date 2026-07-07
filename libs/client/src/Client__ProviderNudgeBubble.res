// Nudge bubble shown near the settings icon urging first-time users to connect an AI provider
// Dismissible per session, re-appears on page reload until a provider is configured

module Button = Client__UI__Button
module Card = Client__UI__Card
module Icons = Client__UI__Icons

@react.component
let make = (~onOpenSettings: unit => unit, ~onDismiss: unit => unit) => {
  <div
    className="absolute top-full right-0 z-50 mt-2 w-64 animate-in fade-in slide-in-from-top-2 duration-300"
  >
    <Card size=Card.Size.Sm>
      <Card.Header>
        <Card.Action>
          <Button variant=Button.Variant.Ghost size=Button.Size.IconXs onClick={_ => onDismiss()}>
            <Icons.Cross2Icon />
          </Button>
        </Card.Action>
        <Card.Title> {React.string("Connect your AI provider")} </Card.Title>
        <Card.Description>
          {React.string("Link Anthropic, OpenAI, or OpenRouter to get started.")}
        </Card.Description>
      </Card.Header>
      <Card.Content>
        <Button
          variant=Button.Variant.Secondary
          size=Button.Size.Sm
          className="w-full"
          onClick={_ => onOpenSettings()}
        >
          {React.string("Open Settings")}
        </Button>
      </Card.Content>
    </Card>
  </div>
}
