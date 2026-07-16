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
  test("rejects duplicate catalog IDs", t => {
    Expect.toThrow(t->expect(() => Client__Agent.validateCatalogOrThrow([planner, planner])))
  })
})
