open Vitest

module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let planner: ACP.agentCatalogEntry = {
  id: "planner-id",
  name: "planner",
  displayName: "Planner",
  description: "Read-only planning",
  color: "#F59E0B",
}

describe("Agent catalog", () => {
  test("preserves exact color supplied by server", t => {
    let agent = Client__Agent.findOrThrow(Some([planner]), "planner-id")

    t->expect(agent.id)->Expect.toBe("planner-id")
    t->expect(agent.name)->Expect.toBe("planner")
    t->expect(agent.displayName)->Expect.toBe("Planner")
    t->expect(agent.color)->Expect.toBe("#F59E0B")
  })

  test("fails without a catalog", t => {
    Expect.toThrow(t->expect(() => Client__Agent.findOrThrow(None, "planner-id")))
  })

  test("fails for an unknown agent ID", t => {
    Expect.toThrow(t->expect(() => Client__Agent.findOrThrow(Some([planner]), "missing-id")))
  })

  test("rejects duplicate catalog IDs", t => {
    Expect.toThrow(t->expect(() => Client__Agent.validateCatalogOrThrow([planner, planner])))
  })
})
