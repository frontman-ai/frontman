open Vitest

module ACP = FrontmanProtocol__ACP

test("session/new Sury conversion emits standard keys and optional namespaced identity", t => {
  let params: ACP.sessionNewParams = {
    cwd: "/",
    mcpServers: [],
    additionalDirectories: None,
    _meta: Some({sessionId: Some("12345678-1234-1234-1234-123456789abc")}),
  }
  let wire = params->S.decodeOrThrow(~from=ACP.sessionNewParamsSchema, ~to=S.json)
  t
  ->expect(wire)
  ->Expect.toEqual(
    JSON.parseOrThrow(`{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":"12345678-1234-1234-1234-123456789abc"}}`),
  )
  t->expect(wire->S.parseOrThrow(~to=ACP.sessionNewParamsSchema))->Expect.toEqual(params)
})

test("session/new accepts standard params, null metadata, and unrelated metadata", t => {
  [
    `{"cwd":"/","mcpServers":[]}`,
    `{"cwd":"/","mcpServers":[],"_meta":null}`,
    `{"cwd":"/","mcpServers":[],"_meta":{"other.vendor/trace":{"opaque":true}}}`,
  ]->Array.forEach(wire => {
    let params = wire->JSON.parseOrThrow->S.parseOrThrow(~to=ACP.sessionNewParamsSchema)
    t->expect(params.cwd)->Expect.toBe("/")
    t->expect(params._meta->Option.flatMap(meta => meta.sessionId))->Expect.toEqual(None)
  })
})

test("session/new rejects legacy root ID and unsupported or malformed configuration", t => {
  [
    `{"sessionId":"legacy"}`,
    `{"cwd":"/","mcpServers":[],"sessionId":"legacy"}`,
    `{"cwd":"relative","mcpServers":[]}`,
    `{"cwd":"/","mcpServers":{}}`,
    `{"cwd":"/","mcpServers":[{"name":"stdio","command":"/bin/server","args":[],"env":[]}]}`,
    `{"cwd":"/","mcpServers":[],"additionalDirectories":["/another"]}`,
    `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":"invalid"}}`,
    `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":null}}`,
  ]->Array.forEach(wire => {
    let parse = () =>
      wire->JSON.parseOrThrow->S.parseOrThrow(~to=ACP.sessionNewParamsSchema)->ignore
    t->expect(parse)->Expect.toThrow
  })
})
