open Vitest

module ToolRegistry = FrontmanCore__ToolRegistry
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

let makeTool = (~name, ~description="generated"): ToolRegistry.tool => {
  module Generated = {
    let name = name
    let description = description
    let access = Tool.Read
    let visibleToAgent = true
    let outputJsonSchema = None

    @schema
    type input = {}

    let execute = async (_context, _input) => MCP.CallToolResult.makeText("ok")
  }
  module(Generated)
}

let toolAtDefinitionLimit = index => {
  let name = `generated_${index->Int.toString}`
  let baseline = makeTool(~name, ~description="")
  let padding = ToolRegistry.definitionByteLimit - baseline->ToolRegistry.definitionByteLength
  makeTool(~name, ~description="x"->String.repeat(padding))
}

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

  test("enforces valid unique names and the inclusive 256-tool boundary", t => {
    let tools = Array.fromInitializer(
      ~length=ToolRegistry.toolLimit,
      index => makeTool(~name=`tool_${index->Int.toString}`),
    )
    let registry = ToolRegistry.make()->ToolRegistry.addTools(tools)
    t->expect(registry->ToolRegistry.count)->Expect.toBe(ToolRegistry.toolLimit)
    t
    ->expect(() => registry->ToolRegistry.addTools([makeTool(~name="tool_over")]))
    ->Expect.toThrow
    t
    ->expect(
      () =>
        ToolRegistry.make()->ToolRegistry.addTools([
          makeTool(~name="duplicate"),
          makeTool(~name="duplicate"),
        ]),
    )
    ->Expect.toThrow
    t
    ->expect(() => ToolRegistry.make()->ToolRegistry.addTools([makeTool(~name="bad name")]))
    ->Expect.toThrow
  })

  test("enforces inclusive per-definition and aggregate UTF-8 byte limits", t => {
    let atLimit = toolAtDefinitionLimit(1)
    t
    ->expect(atLimit->ToolRegistry.definitionByteLength)
    ->Expect.toBe(ToolRegistry.definitionByteLimit)
    ToolRegistry.make()->ToolRegistry.addTools([atLimit])->ignore

    let overLimit = makeTool(
      ~name="generated_over",
      ~description="x"->String.repeat(
        ToolRegistry.definitionByteLimit -
        makeTool(~name="generated_over", ~description="")->ToolRegistry.definitionByteLength + 1,
      ),
    )
    t
    ->expect(() => ToolRegistry.make()->ToolRegistry.addTools([overLimit]))
    ->Expect.toThrow

    let aggregateTools = Array.fromInitializer(
      ~length=16,
      index => toolAtDefinitionLimit(index + 1),
    )
    let aggregate = ToolRegistry.make()->ToolRegistry.addTools(aggregateTools)
    t->expect(aggregate->ToolRegistry.count)->Expect.toBe(16)
    t
    ->expect(() => aggregate->ToolRegistry.addTools([toolAtDefinitionLimit(17)]))
    ->Expect.toThrow
  })

  test("merge combines two registries", t => {
    let a = ToolRegistry.make()->ToolRegistry.addTools([module(FrontmanCore__Tool__ReadFile)])
    let b = ToolRegistry.make()->ToolRegistry.addTools([module(FrontmanCore__Tool__WriteFile)])
    let merged = ToolRegistry.merge(a, b)

    t->expect(merged->ToolRegistry.count)->Expect.toBe(2)
    t->expect(merged->ToolRegistry.getToolByName("read_file")->Option.isSome)->Expect.toBe(true)
    t->expect(merged->ToolRegistry.getToolByName("write_file")->Option.isSome)->Expect.toBe(true)
  })

  test("serializes visible MCP tools in deterministic name order", t => {
    let first =
      ToolRegistry.make()->ToolRegistry.addTools([
        module(FrontmanCore__Tool__WriteFile),
        module(FrontmanCore__Tool__LoadAgentInstructions),
        module(FrontmanCore__Tool__ReadFile),
      ])
    let second =
      ToolRegistry.make()->ToolRegistry.addTools([
        module(FrontmanCore__Tool__ReadFile),
        module(FrontmanCore__Tool__LoadAgentInstructions),
        module(FrontmanCore__Tool__WriteFile),
      ])
    let firstDefinitions = first->ToolRegistry.getMCPToolDefinitions
    let secondDefinitions = second->ToolRegistry.getMCPToolDefinitions
    let names = (definitions: array<MCP.Tool.t>) =>
      definitions->Array.map(definition => definition.name)
    let readDefinition = firstDefinitions->Array.get(0)->Option.getOrThrow
    let writeDefinition = firstDefinitions->Array.get(1)->Option.getOrThrow
    let readAnnotations =
      readDefinition.annotations
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=MCP.ToolAnnotations.knownFieldsSchema)

    t->expect(firstDefinitions->names)->Expect.toEqual(["read_file", "write_file"])
    t->expect(secondDefinitions->names)->Expect.toEqual(firstDefinitions->names)
    t
    ->expect(readDefinition.description)
    ->Expect.toEqual(Some(FrontmanCore__Tool__ReadFile.description))
    t
    ->expect(readDefinition.inputSchema->MCP.ToolSchema.toJson)
    ->Expect.toEqual(FrontmanCore__Tool__ReadFile.inputSchema->S.toJSONSchema->jsonSchemaAsJson)
    t
    ->expect(readDefinition.outputSchema->Option.map(MCP.ToolSchema.toJson))
    ->Expect.toEqual(FrontmanCore__Tool__ReadFile.outputJsonSchema->Option.map(jsonSchemaAsJson))
    t->expect(readAnnotations.readOnlyHint)->Expect.toEqual(Some(true))
    t
    ->expect(
      writeDefinition._meta->Option.flatMap(
        metadata => metadata->Dict.get("ai.frontman/attachment-resolution"),
      ),
    )
    ->Expect.toEqual(
      Some(
        JSON.parseOrThrow(`{"version":1,"referenceArgument":"image_ref","contentArgument":"content","encodingArgument":"encoding","encodingValue":"base64","removeReference":true,"mediaTypeArgument":null}`),
      ),
    )
  })
})
