open Vitest

module ToolRegistry = FrontmanCore__ToolRegistry

describe("ToolRegistry", _t => {
  test("make creates empty registry", t => {
    let registry = ToolRegistry.make()

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0)
  })

  test("finds tool by name", t => {
    let registry = ToolRegistry.coreTools()

    t->expect(registry->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("list_files")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("file_exists")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)->Expect.toBe(false)
  })

  test("addTools extends registry", t => {
    let registry = ToolRegistry.make()
    let extended = registry->ToolRegistry.addTools([
      module(FrontmanCore__Tool__ReadFile),
    ])

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0) // original unchanged
    t->expect(extended->ToolRegistry.count)->Expect.toBe(1)
  })

  test("merge combines two registries", t => {
    let a = ToolRegistry.make()->ToolRegistry.addTools([
      module(FrontmanCore__Tool__ReadFile),
    ])
    let b = ToolRegistry.make()->ToolRegistry.addTools([
      module(FrontmanCore__Tool__WriteFile),
    ])
    let merged = ToolRegistry.merge(a, b)

    t->expect(merged->ToolRegistry.count)->Expect.toBe(2)
    t->expect(merged->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(merged->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
  })

  test("serializes tools with correct structure", t => {
    let registry = ToolRegistry.coreTools()
    let definitions = registry->ToolRegistry.getToolDefinitions
    let readFile = definitions->Array.find(d => d.name == "read_file")

    t->expect(readFile->Option.isSome)->Expect.toBe(true)
    switch readFile {
    | Some(tool) =>
      t->expect(tool.name)->Expect.toBe("read_file")
      t->expect(tool.description->String.length > 0)->Expect.toBe(true)
    | None => ()
    }
  })
})
