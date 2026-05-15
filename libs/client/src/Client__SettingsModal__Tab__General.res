module Button = Client__UI__Button
module Card = Client__UI__Card
module Item = Client__UI__Item
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
        <Card.Content>
          <Item>
            <Item.Media>
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
            </Item.Media>
            <Item.Content>
              {switch userEmail {
              | Some(email) => <Item.Title> {React.string(email)} </Item.Title>
              | None => <Item.Title> {React.string("Loading...")} </Item.Title>
              }}
              <Item.Description> {React.string("Signed in via OAuth")} </Item.Description>
            </Item.Content>
            {switch acpSession {
            | Types.AcpSessionActive({apiBaseUrl}) =>
              <Item.Actions>
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
              </Item.Actions>
            | _ => React.null
            }}
          </Item>
        </Card.Content>
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
