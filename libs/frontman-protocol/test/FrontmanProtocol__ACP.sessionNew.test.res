open Vitest

module ACP = FrontmanProtocol__ACP

let standard: ACP.sessionNewParams = {
  cwd: "/",
  mcpServers: [],
  additionalDirectories: None,
  _meta: None,
}
let retryId = "12345678-1234-1234-1234-123456789abc"
let retry = {...standard, _meta: Some({sessionId: Some(retryId)})}
let standardWire = `{"cwd":"/","mcpServers":[]}`
let retryWire = `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":"12345678-1234-1234-1234-123456789abc"}}`

[
  ("standard params", standard, standardWire),
  ("namespaced retry identity", retry, retryWire),
]->Array.forEach(((name, params, wire)) => {
  test(`session/new serializes ${name}`, t => {
    t
    ->expect(params->S.decodeOrThrow(~from=ACP.sessionNewParamsSchema, ~to=S.json))
    ->Expect.toEqual(JSON.parseOrThrow(wire))
  })
})

[
  ("standard params", standardWire, standard),
  ("namespaced retry identity", retryWire, retry),
  ("null metadata", `{"cwd":"/","mcpServers":[],"_meta":null}`, standard),
  (
    "unrelated metadata",
    `{"cwd":"/","mcpServers":[],"_meta":{"other.vendor/trace":{"opaque":true}}}`,
    {...standard, _meta: Some({sessionId: None})},
  ),
]->Array.forEach(((name, wire, expected)) => {
  test(`session/new parses ${name}`, t => {
    t
    ->expect(wire->JSON.parseOrThrow->S.parseOrThrow(~to=ACP.sessionNewParamsSchema))
    ->Expect.toEqual(expected)
  })
})

[
  ("missing cwd", `{"mcpServers":[]}`, ["cwd"]),
  ("missing mcpServers", `{"cwd":"/"}`, ["mcpServers"]),
  ("legacy root identity", `{"cwd":"/","mcpServers":[],"sessionId":"legacy"}`, []),
  ("relative cwd", `{"cwd":"relative","mcpServers":[]}`, ["cwd"]),
  ("non-string cwd", `{"cwd":42,"mcpServers":[]}`, ["cwd"]),
  ("non-array mcpServers", `{"cwd":"/","mcpServers":{}}`, ["mcpServers"]),
  (
    "configured MCP server",
    `{"cwd":"/","mcpServers":[{"name":"stdio","command":"/bin/server","args":[],"env":[]}]}`,
    ["mcpServers"],
  ),
  (
    "additional directory",
    `{"cwd":"/","mcpServers":[],"additionalDirectories":["/another"]}`,
    ["additionalDirectories"],
  ),
  (
    "invalid retry identity",
    `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":"invalid"}}`,
    ["_meta", "frontman.dev/sessionId"],
  ),
  (
    "null retry identity",
    `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":null}}`,
    ["_meta", "frontman.dev/sessionId"],
  ),
]->Array.forEach(((name, wire, path)) => {
  test(`session/new rejects ${name}`, t => {
    let json = JSON.parseOrThrow(wire)
    let result = try {
      Ok(json->S.parseOrThrow(~to=ACP.sessionNewParamsSchema))
    } catch {
    | S.Exn(error) => Error(error.path->S.Path.toArray)
    }
    t->expect(result)->Expect.toEqual(Error(path))
  })
})
