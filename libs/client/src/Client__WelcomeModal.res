// Welcome modal shown to first-time unauthenticated users
// Auto-redirects to the login page after a countdown

module Dialog = Bindings__UI__Dialog
module Button = Bindings__UI__Button

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

  <Dialog.Dialog open_={true} onOpenChange={_ => ()}>
    <Dialog.DialogContent
      className="sm:max-w-md max-w-md p-0 border-zinc-700 bg-zinc-900" showCloseButton={false}
    >
      <div className="px-8 py-10 text-center">
        // Frontman logo / icon
        <div className="mx-auto mb-6">
          <Client__FrontmanLogo size=48 />
        </div>
        <Dialog.DialogTitle className="text-xl font-bold text-zinc-100">
          {React.string("Welcome to Frontman!")}
        </Dialog.DialogTitle>
        <Dialog.DialogDescription className="mt-3 text-sm text-zinc-400 leading-relaxed">
          {React.string(
            "Your AI-powered coding assistant is ready. Let's get you signed in so you can start building.",
          )}
        </Dialog.DialogDescription>
        // Countdown / progress
        <div className="mt-8 space-y-4">
          <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-zinc-800">
            <div
              className="absolute inset-y-0 left-0 rounded-full bg-gradient-to-r from-violet-500 to-indigo-500 transition-all duration-1000 ease-linear"
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
          <p className="text-xs text-zinc-500">
            {React.string(
              `Redirecting to sign in in ${Int.toString(
                  Int.fromFloat(Math.max(Int.toFloat(countdown), 0.0)),
                )}s...`,
            )}
          </p>
          <Button.Button
            variant=#secondary
            className="mt-2"
            onClick={_ => Client__HostNavigation.assign(~url=loginUrl)}
          >
            {React.string("Sign in now")}
          </Button.Button>
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
