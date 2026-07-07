// Welcome modal shown to first-time unauthenticated users
// Auto-redirects to the login page after a countdown

module Dialog = Client__UI__Dialog
module Button = Client__UI__Button

let redirectDelaySec = 4

@react.component
let make = (~loginUrl: string) => {
  let (countdown, setCountdown) = React.useState(() => redirectDelaySec)

  // Mark FTUE welcome as shown on mount
  React.useEffect0(() => {
    Client__FtueState.setWelcomeShown()
    None
  })

  // Countdown timer → redirect
  React.useEffect0(() => {
    let intervalId = ref(None)

    let id = WebAPI.Global.setInterval2(~handler=() => {
      setCountdown(
        prev => {
          let next = prev - 1
          switch next <= 0 {
          | true =>
            intervalId.contents->Option.forEach(WebAPI.Global.clearInterval)
            Client__HostNavigation.assign(~url=loginUrl)
          | false => ()
          }
          next
        },
      )
    }, ~timeout=1000)

    intervalId := Some(id)

    Some(() => WebAPI.Global.clearInterval(id))
  })

  <Dialog open_={true} onOpenChange={(_, _) => ()}>
    <Dialog.Content className="text-center" showCloseButton={false}>
      <Dialog.Header>
        <div className="mx-auto">
          <Client__FrontmanLogo size=48 />
        </div>
        <Dialog.Title> {React.string("Welcome to Frontman!")} </Dialog.Title>
        <Dialog.Description>
          {React.string(
            "Your AI-powered coding assistant is ready. Let's get you signed in so you can start building.",
          )}
        </Dialog.Description>
      </Dialog.Header>
      <div className="space-y-4">
        <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-muted">
          <div
            className="absolute inset-y-0 left-0 rounded-full bg-primary transition-all duration-1000 ease-linear"
            style={{
              width: `${Int.toString(
                  Float.toInt(
                    Int.toFloat(redirectDelaySec - countdown) /.
                    Int.toFloat(redirectDelaySec) *. 100.0,
                  ),
                )}%`,
            }}
          />
        </div>
        <p className="text-xs text-muted-foreground">
          {React.string(
            `Redirecting to sign in in ${Int.toString(
                Int.fromFloat(Math.max(Int.toFloat(countdown), 0.0)),
              )}s...`,
          )}
        </p>
        <Button
          variant=Button.Variant.Secondary
          onClick={_ => Client__HostNavigation.assign(~url=loginUrl)}
        >
          {React.string("Sign in now")}
        </Button>
      </div>
    </Dialog.Content>
  </Dialog>
}
