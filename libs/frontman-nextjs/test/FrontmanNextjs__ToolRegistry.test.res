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

  test("serializes tools with correct structure", t => {
    let registry = ToolRegistry.make()
    let definitions = registry->ToolRegistry.getToolDefinitions
    let object = tool => tool->JSON.Decode.object->Option.getOrThrow
    let fieldString = (tool, field) =>
      object(tool)->Dict.get(field)->Option.flatMap(JSON.Decode.string)
    let readFile = definitions->Array.find(d => fieldString(d, "name") == Some("read_file"))

    t->expect(readFile->Option.isSome)->Expect.toBe(true)
    switch readFile {
    | Some(tool) =>
      t->expect(fieldString(tool, "name"))->Expect.toEqual(Some("read_file"))
      t
      ->expect(fieldString(tool, "description")->Option.getOrThrow->String.length > 0)
      ->Expect.toBe(true)
    | None => ()
    }
  })
})
