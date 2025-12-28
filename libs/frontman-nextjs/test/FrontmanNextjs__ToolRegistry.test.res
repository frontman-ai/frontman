open Vitest

module ToolRegistry = FrontmanNextjs__ToolRegistry

describe("ToolRegistry", _t => {
  test("creates with default tools", t => {
    let registry = ToolRegistry.make()
    let definitions = registry->ToolRegistry.getToolDefinitions

    // 5 core tools + 2 Next.js tools (get_routes, get_logs)
    t->expect(definitions->Array.length)->Expect.toBe(7)
  })

  test("finds tool by name", t => {
    let registry = ToolRegistry.make()

    t->expect(registry->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("list_files")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("file_exists")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)->Expect.toBe(false)
  })

  test("serializes tools with correct structure", t => {
    let registry = ToolRegistry.make()
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
