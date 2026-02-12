open Vitest

module ToolRegistry = Client__ToolRegistry

describe("ToolRegistry", _t => {
  test("make creates empty registry", t => {
    let registry = ToolRegistry.make()

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0)
  })

  test("coreBrowserTools returns all browser tools", t => {
    let registry = ToolRegistry.coreBrowserTools()

    t->expect(registry->ToolRegistry.count)->Expect.toBe(2)
  })

  test("finds tool by name", t => {
    let registry = ToolRegistry.coreBrowserTools()

    t->expect(registry->ToolRegistry.getToolByName("take_screenshot")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("navigate")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)->Expect.toBe(false)
  })

  test("addTools extends registry", t => {
    let registry = ToolRegistry.make()
    let extended = registry->ToolRegistry.addTools([
      module(Client__Tool__Navigate),
    ])

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0) // original unchanged
    t->expect(extended->ToolRegistry.count)->Expect.toBe(1)
  })

  test("merge combines two registries", t => {
    let a = ToolRegistry.make()->ToolRegistry.addTools([
      module(Client__Tool__Navigate),
    ])
    let b = ToolRegistry.make()->ToolRegistry.addTools([
      module(Client__Tool__TakeScreenshot),
    ])
    let merged = ToolRegistry.merge(a, b)

    t->expect(merged->ToolRegistry.count)->Expect.toBe(2)
    t->expect(merged->ToolRegistry.getToolByName("navigate")->Option.isSome)->Expect.toBe(true)
    t->expect(merged->ToolRegistry.getToolByName("take_screenshot")->Option.isSome)->Expect.toBe(true)
  })
})
