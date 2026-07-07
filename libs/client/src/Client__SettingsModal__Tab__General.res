module Button = Client__UI__Button
module Card = Client__UI__Card
module Avatar = Client__UI__Avatar
module Alert = Client__UI__Alert
module Field = Client__UI__Field
module Billing = Client__Billing
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

let renderBillingRequiredAlert = (billingStatus: Billing.state) =>
  switch billingStatus {
  | Billing.Loaded(status) =>
    switch Billing.isAccessAllowed(status) {
    | true => React.null
    | false =>
      <Alert className="border-amber-500/30 bg-amber-500/10 text-amber-950 dark:text-amber-100">
        <Alert.Title> {React.string("Billing required")} </Alert.Title>
        <Alert.Description className="text-amber-900/80 dark:text-amber-100/80">
          {React.string("You must set up billing to use Frontman.")}
        </Alert.Description>
        <Alert.Action>
          <Button
            variant=Button.Variant.Secondary
            size=Button.Size.Sm
            onClick={_ => State.Actions.openSettingsModalOnBilling()}
          >
            {React.string("Open Billing")}
          </Button>
        </Alert.Action>
      </Alert>
    }
  | Billing.NotLoaded | Billing.Error(_) => React.null
  }

@react.component
let make = () => {
  let runtimeConfig = RuntimeConfig.read()
  let frameworkDisplayName = RuntimeConfig.frameworkDisplayName(runtimeConfig.framework)
  let userProfile = State.useSelector(State.Selectors.userProfile)
  let userEmail = userProfile->Option.map(p => p.email)
  let acpSession = State.useSelector(State.Selectors.acpSession)
  let billingStatus = State.useSelector(State.Selectors.billingStatus)

  <div className="space-y-6">
    {renderBillingRequiredAlert(billingStatus)}
    <Field.Set>
      <Field.Legend variant=Field.Variant.Label> {React.string("Account")} </Field.Legend>
      <Card size=Card.Size.Sm>
        <Card.Header
          className="grid-cols-[auto_1fr] items-center gap-x-3 has-data-[slot=card-action]:grid-cols-[auto_1fr_auto]"
        >
          {switch acpSession {
          | Types.AcpSessionActive({apiBaseUrl}) =>
            <Card.Action className="col-start-3 self-center">
              <Button
                variant=Button.Variant.Outline
                size=Button.Size.Sm
                onClick={_ => {
                  // Preserve server logout redirect back to current client URL.
                  let encodeURIComponent: string => string = %raw(`encodeURIComponent`)
                  let currentUrl = Client__HostNavigation.currentUrl()
                  let returnTo = encodeURIComponent(currentUrl)
                  Client__HostNavigation.assign(
                    ~url=`${apiBaseUrl}/users/log-out?return_to=${returnTo}`,
                  )
                }}
              >
                {React.string("Sign out")}
              </Button>
            </Card.Action>
          | _ => React.null
          }}
          <div className="row-span-2 row-start-1 flex">
            <Avatar>
              <Avatar.Fallback>
                {React.string(
                  switch userEmail {
                  | Some(email) => email->String.charAt(0)->String.toUpperCase
                  | None => "?"
                  },
                )}
              </Avatar.Fallback>
            </Avatar>
          </div>
          {switch userEmail {
          | Some(email) =>
            <Card.Title className="col-start-2 row-start-1 min-w-0 truncate">
              {React.string(email)}
            </Card.Title>
          | None =>
            <Card.Title className="col-start-2 row-start-1">
              {React.string("Loading...")}
            </Card.Title>
          }}
          <Card.Description className="col-start-2 row-start-2">
            {React.string("Signed in via OAuth")}
          </Card.Description>
        </Card.Header>
      </Card>
    </Field.Set>
    <Field.Set>
      <Field.Legend variant=Field.Variant.Label> {React.string("Environment")} </Field.Legend>
      <Alert>
        <Alert.Description>
          {React.string(`Framework detected: ${frameworkDisplayName}`)}
        </Alert.Description>
      </Alert>
    </Field.Set>
  </div>
}
