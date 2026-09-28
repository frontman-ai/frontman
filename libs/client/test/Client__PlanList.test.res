open Vitest

module PlanList = Client__PlanList
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let entry = (status: ACPTypes.planEntryStatus): ACPTypes.planEntry => {
  content: "Test step",
  priority: Medium,
  status,
}

describe("PlanList visibility", () => {
  test("hides an empty plan", t => {
    let entries: array<ACPTypes.planEntry> = []
    t->expect(PlanList.shouldRender(entries))->Expect.toEqual(false)
  })

  test("hides a fully completed plan", t => {
    let entries = [entry(Completed), entry(Completed)]
    t->expect(PlanList.shouldRender(entries))->Expect.toEqual(false)
  })

  test("shows a plan with unfinished entries", t => {
    let entries = [entry(Completed), entry(InProgress)]
    t->expect(PlanList.shouldRender(entries))->Expect.toEqual(true)
  })
})
