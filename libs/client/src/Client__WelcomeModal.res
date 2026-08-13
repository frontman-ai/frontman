module Dialog = Client__UI__Dialog
module Button = Client__UI__Button

let redirectDelaySec = 4

@react.component
let make = (~loginUrl: string, ~markWelcomeShown: bool) => {
  let embedded = Client__HostNavigation.useTopWindow(
    ~currentWindow=WebAPI.Global.window,
    ~topWindow=WebAPI.Global.top,
  )
  let (countdown, setCountdown) = React.useState(() => redirectDelaySec)
  let (popupBlocked, setPopupBlocked) = React.useState(() => false)

  React.useEffect0(() => {
    switch markWelcomeShown {
    | true => Client__FtueState.setWelcomeShown()
    | false => ()
    }
    None
  })

  React.useEffect0(() =>
    switch embedded {
    | true => None
    | false =>
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
    }
  )

  <Dialog open_={true} onOpenChange={(_, _) => ()}>
    <Dialog.Content className="text-center" showCloseButton={false}>
      <Dialog.Header>
        <div className="mx-auto">
          <Client__FrontmanLogo size=48 />
        </div>
        <Dialog.Title> {React.string("Welcome to Frontman!")} </Dialog.Title>
        <Dialog.Description>
          {React.string("Sign in to Frontman to start setting up your coding assistant.")}
        </Dialog.Description>
      </Dialog.Header>
      <div className="space-y-4">
        <p className="text-xs text-muted-foreground">
          {React.string(
            switch embedded {
            | true => "Sign in opens in a new tab. Continue there, then return to this page."
            | false =>
              `Redirecting to sign in in ${Int.toString(
                  Int.fromFloat(Math.max(Int.toFloat(countdown), 0.0)),
                )}s...`
            },
          )}
        </p>
        {switch popupBlocked {
        | true =>
          <p className="text-xs text-destructive" role="alert">
            {React.string("Your browser blocked the sign-in tab. Allow popups and try again.")}
          </p>
        | false => React.null
        }}
        <Button
          variant=Button.Variant.Secondary
          onClick={_ => {
            let opened = Client__HostNavigation.openLogin(~url=loginUrl)
            setPopupBlocked(_ => !opened)
          }}
        >
          {React.string("Sign in now")}
        </Button>
      </div>
    </Dialog.Content>
  </Dialog>
}
