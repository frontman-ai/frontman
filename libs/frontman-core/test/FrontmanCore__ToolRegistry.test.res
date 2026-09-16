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
    t
    ->expect(registry->ToolRegistry.getToolByName("nonexistent")->Option.isSome)
    ->Expect.toBe(false)
  })

  test("addTools extends registry", t => {
    let registry = ToolRegistry.make()
    let extended = registry->ToolRegistry.addTools([module(FrontmanCore__Tool__ReadFile)])

    t->expect(registry->ToolRegistry.count)->Expect.toBe(0)
    t->expect(extended->ToolRegistry.count)->Expect.toBe(1)
  })

  test("merge combines two registries", t => {
    let a = ToolRegistry.make()->ToolRegistry.addTools([module(FrontmanCore__Tool__ReadFile)])
    let b = ToolRegistry.make()->ToolRegistry.addTools([module(FrontmanCore__Tool__WriteFile)])
    let merged = ToolRegistry.merge(a, b)

    t->expect(merged->ToolRegistry.count)->Expect.toBe(2)
    t->expect(merged->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(merged->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
  })

  test("serializes metadata and only real output schemas", t => {
    let definitions = ToolRegistry.coreTools()->ToolRegistry.getToolDefinitions
    let object = tool => tool->JSON.Decode.object->Option.getOrThrow
    let name = tool => object(tool)->Dict.get("name")->Option.flatMap(JSON.Decode.string)
    let metadata = tool =>
      object(tool)
      ->Dict.get("_meta")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(meta => meta->Dict.get("ai.frontman/tool-metadata"))
      ->Option.flatMap(JSON.Decode.object)
    let readFile = definitions->Array.find(d => name(d) == Some("read_file"))->Option.getOrThrow
    let listFiles = definitions->Array.find(d => name(d) == Some("list_files"))->Option.getOrThrow

    t
    ->expect(
      metadata(readFile)
      ->Option.flatMap(meta => meta->Dict.get("access"))
      ->Option.flatMap(JSON.Decode.string),
    )
    ->Expect.toEqual(Some("read"))
    t->expect(object(readFile)->Dict.get("outputSchema")->Option.isSome)->Expect.toBe(true)
    t->expect(object(listFiles)->Dict.get("outputSchema"))->Expect.toEqual(None)
  })
})
