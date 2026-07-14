open Vitest

module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

describe("Agent config", () => {
  test("reads explicit agent ID from user message metadata", t => {
    let meta =
      Dict.fromArray([
        ("frontman.dev/agentId", JSON.Encode.string("executor-id")),
      ])->JSON.Encode.object

    t->expect(Client__Agent.messageAgentId(Some(meta)))->Expect.toBe("executor-id")
  })

  test("preserves exact color supplied by server", t => {
    let meta =
      Dict.fromArray([
        ("frontman.dev/agentColor", JSON.Encode.string("#F59E0B")),
        ("frontman.dev/agentName", JSON.Encode.string("planner")),
      ])->JSON.Encode.object
    let config = ACP.SelectConfigOption({
      id: "agent",
      name: "Agent",
      description: None,
      category: Some(Mode),
      options: Ungrouped([
        {
          value: "planner-id",
          name: "Planner",
          description: Some("Read-only planning"),
          _meta: Some(meta),
        },
      ]),
      _meta: None,
    })

    let agent = Client__Agent.findOrThrow([config], "planner-id")

    t->expect(agent.name)->Expect.toBe("planner")
    t->expect(agent.displayName)->Expect.toBe("Planner")
    t->expect(agent.color)->Expect.toBe("#F59E0B")
  })

  test("fails when server omits explicit color", t => {
    let meta =
      Dict.fromArray([
        ("frontman.dev/agentName", JSON.Encode.string("planner")),
      ])->JSON.Encode.object
    let config = ACP.SelectConfigOption({
      id: "agent",
      name: "Agent",
      description: None,
      category: Some(Mode),
      options: Ungrouped([
        {
          value: "planner-id",
          name: "Planner",
          description: None,
          _meta: Some(meta),
        },
      ]),
      _meta: None,
    })

    Expect.toThrow(t->expect(() => Client__Agent.findOrThrow([config], "planner-id")))
  })
})
