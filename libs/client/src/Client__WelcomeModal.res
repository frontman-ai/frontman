module Dialog = Client__UI__Dialog
module Button = Client__UI__Button

@react.component
let make = (~loginUrl: string) => {
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
          {React.string("Sign in in a new tab, then return here.")}
        </p>
        <a
          href={loginUrl}
          target="_blank"
          rel="noopener noreferrer"
          className={Button.buttonVariants(~variant=Button.Variant.Secondary)}
        >
          {React.string("Sign in")}
        </a>
        <a
          href={WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href}
          className={Button.buttonVariants(~variant=Button.Variant.Secondary)}
        >
          {React.string("I've signed in")}
        </a>
      </div>
    </Dialog.Content>
  </Dialog>
}
