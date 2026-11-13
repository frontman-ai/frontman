module Button = Client__UI__Button
module Dialog = Client__UI__Dialog

@react.component
let make = (
  ~open_: bool,
  ~onOpenSettings: unit => unit,
  ~onConnectAssistant: option<unit => unit>=?,
) => {
  <Dialog open_ onOpenChange={(_, _) => ()}>
    <Dialog.Content
      className={onConnectAssistant->Option.isSome
        ? "frontman-onboarding sm:max-w-3xl max-h-[calc(100dvh-2rem)] overflow-y-auto p-6 sm:p-8 gap-6 text-foreground ring-border"
        : "sm:max-w-md"}
      showCloseButton=false
    >
      {switch onConnectAssistant {
      | Some(connectAssistant) =>
        <>
          <Dialog.Header className="gap-3">
            <Dialog.Title
              className="text-2xl sm:text-3xl font-semibold leading-tight tracking-tight"
            >
              {React.string(`Let’s get you started`)}
            </Dialog.Title>
            <Dialog.Description className="text-onboarding-body leading-relaxed">
              {React.string("how would you like to work with frontman?")}
            </Dialog.Description>
          </Dialog.Header>
          <div className="space-y-5">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <section
                ariaLabel="Work with your agent"
                className="flex flex-col rounded-xl border border-ring/45 bg-card p-5"
              >
                <Client__UI__Icons.MessageCircle
                  className="mb-4 size-5 text-onboarding-accent" ariaHidden=true
                />
                <h3 className="text-lg font-medium leading-snug">
                  {React.string("From your favorite agent")}
                </h3>
                <p className="mt-3 text-sm text-onboarding-body leading-relaxed">
                  {React.string(
                    "Rewrite a headline or refresh a page without leaving your conversation.",
                  )}
                </p>
                <div className="mt-auto pt-5">
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    {React.string("No additional AI API key needed for Frontman.")}
                  </p>
                  <Button
                    className="mt-4 h-11 w-full hover:bg-onboarding-primary-hover"
                    onClick={_ => connectAssistant()}
                  >
                    {React.string("Connect your agent")}
                  </Button>
                </div>
              </section>
              <section
                ariaLabel="Work in Frontman"
                className="flex flex-col rounded-xl border border-border bg-card p-5"
              >
                <Client__UI__Icons.Monitor
                  className="mb-4 size-5 text-onboarding-accent" ariaHidden=true
                />
                <h3 className="text-lg font-medium leading-snug">
                  {React.string("Here, with a live preview")}
                </h3>
                <p className="mt-3 text-sm text-onboarding-body leading-relaxed">
                  {React.string("Describe a change beside your website, then inspect the result.")}
                </p>
                <div className="mt-auto pt-5">
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    {React.string("Connect your AI provider. Separate charges may apply.")}
                  </p>
                  <Button
                    variant=Button.Variant.Secondary
                    className="mt-4 h-11 w-full border-border"
                    onClick={_ => onOpenSettings()}
                  >
                    {React.string("Edit in Frontman")}
                  </Button>
                </div>
              </section>
            </div>
            <p className="text-sm text-onboarding-body leading-relaxed">
              <span className="text-muted-foreground">
                {React.string("Start with a request like: ")}
              </span>
              {React.string(`“Make my homepage headline clearer.”`)}
            </p>
            <p
              className="border-t border-border pt-4 text-xs leading-relaxed text-muted-foreground"
            >
              {React.string(
                "Agent access requires an active Frontman subscription or trial, plus WordPress administrator access. Use the same Frontman account here and in your agent.",
              )}
            </p>
          </div>
        </>
      | None =>
        <>
          <Dialog.Header>
            <Dialog.Title>
              {React.string("One last step, then you're ready to build")}
            </Dialog.Title>
            <Dialog.Description>
              {React.string(
                "Frontman uses an AI provider to understand your requests and generate code. Connect one you already use, choose your model, and stay in control of billing.",
              )}
            </Dialog.Description>
          </Dialog.Header>
          <ol className="space-y-3 py-1 text-sm">
            {[
              "Choose a provider you already use",
              "Connect your account or add an API key",
              "Pick a model and start building",
            ]
            ->Array.mapWithIndex((instruction, index) =>
              <li key={instruction} className="flex items-center gap-3">
                <span
                  className="flex size-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-medium text-muted-foreground"
                >
                  {React.int(index + 1)}
                </span>
                <span className="text-foreground/90"> {React.string(instruction)} </span>
              </li>
            )
            ->React.array}
          </ol>
          <Dialog.Footer>
            <Button className="w-full sm:w-auto" onClick={_ => onOpenSettings()}>
              {React.string("Connect AI provider")}
            </Button>
          </Dialog.Footer>
        </>
      }}
    </Dialog.Content>
  </Dialog>
}
