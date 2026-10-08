module Dialog = Client__UI__Dialog
module Button = Client__UI__Button

@react.component
let make = (~loginUrl: string, ~onSignIn: unit => unit) => {
  let draft = Client__State.useSelector(Client__State.Selectors.composerDraft)
  let (waiting, setWaiting) = React.useState(() => false)
  let (error, setError) = React.useState((): option<string> => None)
  let authorizationRef = React.useRef(None)

  React.useEffect0(() => {
    Some(
      () =>
        authorizationRef.current->Option.forEach((
          authorization: Client__EmbeddedAuthPopup.authorization,
        ) => authorization.cancel()),
    )
  })

  let handleSignIn = event => {
    ReactEvent.Mouse.preventDefault(event)
    authorizationRef.current->Option.forEach((
      authorization: Client__EmbeddedAuthPopup.authorization,
    ) => authorization.cancel())
    setWaiting(_ => true)
    setError(_ => None)
    authorizationRef.current = Some(
      Client__EmbeddedAuthPopup.start(
        ~loginUrl,
        ~onSuccess=() => {
          authorizationRef.current = None
          onSignIn()
        },
        ~onError=_error => {
          authorizationRef.current = None
          setWaiting(_ => false)
          setError(_ => Some("Sign-in didn't complete. Try again; your request is still here."))
        },
      ),
    )
  }

  <Dialog open_={true} onOpenChange={(_, _) => ()}>
    <Dialog.Content
      className="sm:max-w-lg max-h-[90dvh] overflow-y-auto p-6" showCloseButton={false}
    >
      <Dialog.Header>
        <div className="mx-auto">
          <Client__FrontmanLogo size=48 />
        </div>
        <Dialog.Title className="text-2xl font-semibold leading-tight">
          {React.string("Your next website improvement starts here.")}
        </Dialog.Title>
        <Dialog.Description>
          {React.string(
            "Less explaining. More delivering. Point to what needs changing, describe the result, and work with your live page context instead of another screenshot handoff.",
          )}
        </Dialog.Description>
      </Dialog.Header>
      <div className="space-y-4">
        <label className="block space-y-2">
          <span className="text-sm font-medium">
            {React.string("What would you like to improve first?")}
          </span>
          <textarea
            rows=3
            value=draft
            placeholder="For example: make the signup section clearer on mobile"
            className="w-full rounded-lg border bg-transparent p-3 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            onChange={event =>
              Client__State.Actions.setComposerDraft(ReactEvent.Form.target(event)["value"])}
          />
        </label>
        <p className="text-sm text-muted-foreground">
          {React.string(
            "Sign in, choose your Frontman plan, then connect a supported AI provider. Provider usage is billed separately. Your draft stays in this tab; nothing runs until you send it.",
          )}
        </p>
        {switch error {
        | Some(error) =>
          <p role="alert" className="text-sm text-destructive"> {React.string(error)} </p>
        | None => React.null
        }}
        <p className="text-xs text-muted-foreground">
          {React.string(
            switch waiting {
            | true => "Waiting for sign-in to complete..."
            | false => "Sign in in a secure popup. Frontman will connect automatically."
            },
          )}
        </p>
        <a
          href={loginUrl}
          target="frontman-embedded-auth"
          className={Button.buttonVariants(~className="w-full min-h-11")}
          onClick=handleSignIn
        >
          {React.string(
            switch waiting {
            | true => "Open sign-in again"
            | false => "Sign in and keep going"
            },
          )}
        </a>
      </div>
    </Dialog.Content>
  </Dialog>
}
