open Vitest

module ToolRegistry = Client__ToolRegistry

describe("ToolRegistry", _t => {
  test("make creates empty registry", t => {
    let registry = ToolRegistry.make()

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0)
  })

  test("coreBrowserTools returns all browser tools", t => {
    let registry = ToolRegistry.coreBrowserTools()

    t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
  })

  test("finds tool by name", t => {
    let registry = ToolRegistry.coreBrowserTools()

    t
    ->expect(registry->ToolRegistry.getToolByName("take_screenshot")->Option.isSome)
    ->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("execute_js")->Option.isSome)->Expect.toBe(true)
    t
    ->expect(registry->ToolRegistry.getToolByName("set_device_mode")->Option.isSome)
    ->Expect.toBe(true)
    t
    ->expect(registry->ToolRegistry.getToolByName("get_interactive_elements")->Option.isSome)
    ->Expect.toBe(true)
    t
    ->expect(registry->ToolRegistry.getToolByName("interact_with_element")->Option.isSome)
    ->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("get_dom")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("search_text")->Option.isSome)->Expect.toBe(true)
    t
    ->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)
    ->Expect.toBe(false)
  })

  test("addTools extends registry", t => {
    let registry = ToolRegistry.make()
    let extended = registry->ToolRegistry.addTools([module(Client__Tool__ExecuteJs)])

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0) // original unchanged
    t->expect(extended->ToolRegistry.count)->Expect.toBe(1)
  })

  test("merge combines two registries", t => {
    let a = ToolRegistry.make()->ToolRegistry.addTools([module(Client__Tool__ExecuteJs)])
    let b = ToolRegistry.make()->ToolRegistry.addTools([module(Client__Tool__TakeScreenshot)])
    let merged = ToolRegistry.merge(a, b)

    t->expect(merged->ToolRegistry.count)->Expect.toBe(2)
    t->expect(merged->ToolRegistry.getToolByName("execute_js")->Option.isSome)->Expect.toBe(true)
    t
    ->expect(merged->ToolRegistry.getToolByName("take_screenshot")->Option.isSome)
    ->Expect.toBe(true)
  })

  describe("forFramework", _t => {
    test(
      "Astro returns core browser tools count",
      t => {
        let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Astro)
        t->expect(registry->ToolRegistry.count)->Expect.toBe(9)
      },
    )

    test(
      "Nextjs returns core browser tools count",
      t => {
        let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Nextjs)
        t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
      },
    )

    test(
      "Vite returns core browser tools count",
      t => {
        let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Vite)
        t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
      },
    )

    test(
      "Wordpress returns core browser tools count",
      t => {
        let registry = ToolRegistry.forFramework(Client__RuntimeConfig.Wordpress)
        t->expect(registry->ToolRegistry.count)->Expect.toBe(8)
      },
    )
  })
})
