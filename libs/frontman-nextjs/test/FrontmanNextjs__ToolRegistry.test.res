open Vitest

module ToolRegistry = FrontmanNextjs__ToolRegistry

describe("ToolRegistry", _t => {
  test("finds tool by name", t => {
    let registry = ToolRegistry.make()

    t->expect(registry->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("list_files")->Option.isSome)->Expect.toBe(true)
    t->expect(registry->ToolRegistry.getToolByName("file_exists")->Option.isSome)->Expect.toBe(true)
    t
    ->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)
    ->Expect.toBe(false)
  })

  test("replaces both filesystem mutation tools", t => {
    let registry = ToolRegistry.make()
    let edit = registry->ToolRegistry.getToolByName("edit_file")->Option.getOrThrow
    let write = registry->ToolRegistry.getToolByName("write_file")->Option.getOrThrow
    module Edit = unpack(edit)
    module Write = unpack(write)

    t->expect(Edit.description)->Expect.toBe(FrontmanNextjs__Tool__EditFile.description)
    t->expect(Write.description)->Expect.toBe(FrontmanNextjs__Tool__WriteFile.description)
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
