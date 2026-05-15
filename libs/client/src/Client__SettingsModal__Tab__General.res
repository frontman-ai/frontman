module Button = Client__UI__Button
module Card = Client__UI__Card
module Avatar = Client__UI__Avatar
module Alert = Client__UI__Alert
module Field = Client__UI__Field
module State = Client__State
module Types = Client__State__Types
module RuntimeConfig = Client__RuntimeConfig

@react.component
let make = () => {
  let runtimeConfig = RuntimeConfig.read()
  let frameworkDisplayName = RuntimeConfig.frameworkDisplayName(runtimeConfig.framework)
  let userProfile = State.useSelector(State.Selectors.userProfile)
  let userEmail = userProfile->Option.map(p => p.email)
  let acpSession = State.useSelector(State.Selectors.acpSession)

  <div className="space-y-6">
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
