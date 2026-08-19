open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

let handle = (request: Types.message<FrontmanProtocol.Preview.capabilityResult>) =>
  switch request {
  | FrontmanProtocol.Preview.GetCapabilities(request) =>
    FrontmanProtocol.Preview.negotiateCapabilities(
      request,
      ~capabilities=[FrontmanProtocol.Preview.Capability.domSerialization],
    )
  | _ => Error({code: "unexpected_message", message: "Unexpected preview message"})
  }

describe("preview capability negotiation", _t => {
  test("returns protocol version and supported capabilities", t => {
    let response = handle(
      FrontmanProtocol.Preview.GetCapabilities({
        protocolMajor: FrontmanProtocol.Preview.protocolMajor,
      }),
    )

    t
    ->expect(response)
    ->Expect.toEqual(
      Ok({
        protocolMajor: FrontmanProtocol.Preview.protocolMajor,
        capabilities: [FrontmanProtocol.Preview.Capability.domSerialization],
      }),
    )
  })

  test("returns typed error for unsupported protocol major", t => {
    let response = handle(FrontmanProtocol.Preview.GetCapabilities({protocolMajor: 99}))

    t
    ->expect(response)
    ->Expect.toEqual(
      Error({
        code: FrontmanProtocol.Preview.ErrorCode.unsupportedProtocolMajor,
        message: "Unsupported preview protocol major 99; supported major is 1",
      }),
    )
  })

  test("response DTO survives structured clone", t => {
    let response: FrontmanProtocol.Preview.capabilityResult = Ok({
      protocolMajor: FrontmanProtocol.Preview.protocolMajor,
      capabilities: [
        FrontmanProtocol.Preview.Capability.domSerialization,
        FrontmanProtocol.Preview.Capability.selection,
      ],
    })

    t->expect(structuredClone(response))->Expect.toEqual(response)
  })

  test("error DTO survives structured clone", t => {
    let error: FrontmanProtocol.Preview.error = {
      code: FrontmanProtocol.Preview.ErrorCode.unsupportedProtocolMajor,
      message: "unsupported",
    }

    t->expect(structuredClone(error))->Expect.toEqual(error)
  })
})
