open Vitest

let popup = () => WebAPI.Window.current

let message = (~origin, ~source=?, ~data): Client__EmbeddedAuthPopup.messageEvent =>
  WebAPI.MessageEvent.make(
    ~type_="message",
    ~eventInitDict={
      data,
      origin,
      source: source->Option.mapOr(Null.null, value => Null.make(value)),
    },
  )

let completionData = (~state="state-123", ~token="token-123", ~messageType=?, ~version=?) =>
  JSON.Encode.object(
    Dict.fromArray([
      (
        "type",
        JSON.Encode.string(
          messageType->Option.getOr(Client__EmbeddedAuthPopup.completionMessageType),
        ),
      ),
      (
        "version",
        JSON.Encode.int(version->Option.getOr(Client__EmbeddedAuthPopup.completionMessageVersion)),
      ),
      ("state", JSON.Encode.string(state)),
      ("token", JSON.Encode.string(token)),
    ]),
  )

describe("EmbeddedAuthPopup", () => {
  test("adds embedded state and origin without losing existing login URL parameters", t => {
    let url = Client__EmbeddedAuthPopup.authorizationUrl(
      ~loginUrl="https://app.frontman.sh/users/log-in?framework=wordpress#password",
      ~state="state-123",
      ~origin="https://customer.example",
    )

    t
    ->expect(url)
    ->Expect.toBe(
      "https://app.frontman.sh/users/log-in?framework=wordpress&embedded_state=state-123&embedded_origin=https%3A%2F%2Fcustomer.example#password",
    )
  })

  test("generates at least 256 bits of authorization state", t => {
    let state = Client__EmbeddedAuthPopup.generateState()

    t->expect(state->String.length)->Expect.toBe(64)
  })

  test("accepts a matching completion message", t => {
    let result = Client__EmbeddedAuthPopup.validateMessage(
      ~event=message(
        ~origin="https://app.frontman.sh",
        ~source=FrontmanBindings.Bindings__WebAPI.messageSourceFromWindow(popup()),
        ~data=completionData(),
      ),
      ~frontmanOrigin="https://app.frontman.sh",
      ~popup=popup(),
      ~state="state-123",
    )

    t->expect(result)->Expect.toEqual(Ok("token-123"))
  })

  test("rejects a completion message from the wrong origin", t => {
    let result = Client__EmbeddedAuthPopup.validateMessage(
      ~event=message(
        ~origin="https://evil.example",
        ~source=FrontmanBindings.Bindings__WebAPI.messageSourceFromWindow(popup()),
        ~data=completionData(),
      ),
      ~frontmanOrigin="https://app.frontman.sh",
      ~popup=popup(),
      ~state="state-123",
    )

    t->expect(result)->Expect.toEqual(Error(Client__EmbeddedAuthPopup.InvalidOrigin))
  })

  test("rejects a completion message from the wrong popup source", t => {
    let result = Client__EmbeddedAuthPopup.validateMessage(
      ~event=message(~origin="https://app.frontman.sh", ~data=completionData()),
      ~frontmanOrigin="https://app.frontman.sh",
      ~popup=popup(),
      ~state="state-123",
    )

    t->expect(result)->Expect.toEqual(Error(Client__EmbeddedAuthPopup.InvalidSource))
  })

  test("rejects a completion message with the wrong state", t => {
    let result = Client__EmbeddedAuthPopup.validateMessage(
      ~event=message(
        ~origin="https://app.frontman.sh",
        ~source=FrontmanBindings.Bindings__WebAPI.messageSourceFromWindow(popup()),
        ~data=completionData(~state="other-state"),
      ),
      ~frontmanOrigin="https://app.frontman.sh",
      ~popup=popup(),
      ~state="state-123",
    )

    t->expect(result)->Expect.toEqual(Error(Client__EmbeddedAuthPopup.InvalidState))
  })
})
