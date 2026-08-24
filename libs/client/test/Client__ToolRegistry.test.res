open Vitest

module ToolRegistry = Client__ToolRegistry
module FrontmanClient = FrontmanAiFrontmanClient
module Relay = FrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanClient.FrontmanClient__MCP__Server
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

let toolDefinitions = framework => {
  let registry = ToolRegistry.forFramework(framework)
  let relay = Relay.make(~baseUrl="http://localhost:3000")
  let server = ToolRegistry.registerAll(registry, MCPServer.make(~relay))
  server
  ->MCPServer.getToolsJson
  ->Array.map(json => json->JSON.Decode.object->Option.getOrThrow)
}

let toolNames = framework =>
  toolDefinitions(framework)->Array.map(obj =>
    obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
  )

let toolByName = (framework, name) =>
  toolDefinitions(framework)
  ->Array.find(obj => obj->Dict.get("name") == Some(JSON.Encode.string(name)))
  ->Option.getOrThrow

describe("ToolRegistry", _t => {
  test("registers core browser tools for non-Astro frameworks", t => {
    let names = toolNames(Client__RuntimeConfig.Nextjs)

    t->expect(names->Array.length)->Expect.toBe(8)
    t->expect(names->Array.includes("take_screenshot"))->Expect.toBe(true)
    t->expect(names->Array.includes("execute_js"))->Expect.toBe(true)
    t->expect(names->Array.includes("set_device_mode"))->Expect.toBe(true)
    t->expect(names->Array.includes("get_interactive_elements"))->Expect.toBe(true)
    t->expect(names->Array.includes("interact_with_element"))->Expect.toBe(true)
    t->expect(names->Array.includes("get_dom"))->Expect.toBe(true)
    t->expect(names->Array.includes("search_text"))->Expect.toBe(true)
  })

  test("adds Astro browser tools only for Astro", t => {
    let astroNames = toolNames(Client__RuntimeConfig.Astro)
    let viteNames = toolNames(Client__RuntimeConfig.Vite)
    let wordpressNames = toolNames(Client__RuntimeConfig.Wordpress)

    t->expect(astroNames->Array.length)->Expect.toBe(9)
    t->expect(astroNames->Array.includes("get_astro_audit"))->Expect.toBe(true)
    t->expect(viteNames->Array.length)->Expect.toBe(8)
    t->expect(viteNames->Array.includes("get_astro_audit"))->Expect.toBe(false)
    t->expect(wordpressNames->Array.length)->Expect.toBe(8)
    t->expect(wordpressNames->Array.includes("get_astro_audit"))->Expect.toBe(false)
  })

  test("serializes browser tool access levels", t => {
    let access = name => toolByName(Client__RuntimeConfig.Nextjs, name)->Dict.get("access")

    t->expect(access("take_screenshot"))->Expect.toEqual(Some(JSON.Encode.string("read")))
    t->expect(access("execute_js"))->Expect.toEqual(Some(JSON.Encode.string("read-write")))
    t->expect(access("set_device_mode"))->Expect.toEqual(Some(JSON.Encode.string("write")))
  })

  test("advertises only structured browser output schemas", t => {
    toolDefinitions(Client__RuntimeConfig.Astro)->Array.forEach(
      tool => {
        let isScreenshot = tool->Dict.get("name") == Some(JSON.Encode.string("take_screenshot"))
        t->expect(tool->Dict.has("outputSchema"))->Expect.toBe(!isScreenshot)
      },
    )
  })

  test("screenshot data becomes image content", t => {
    let result = Client__Tool__TakeScreenshot.imageResultFromDataUrl(
      "data:image/jpeg;base64,image-data",
    )

    let json = result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)
    t
    ->expect(JSON.stringify(json))
    ->Expect.toBe(`{"content":[{"type":"image","data":"image-data","mimeType":"image/jpeg"}]}`)
  })

  test("explains generated image decode failures", t => {
    let message = Client__Tool__TakeScreenshot.captureErrorMessage(
      "The source image cannot be decoded.",
    )
    let alternateMessage = Client__Tool__TakeScreenshot.captureErrorMessage(
      "Invalid encoded image data",
    )

    t->expect(message->String.includes("generated page image"))->Expect.toBe(true)
    t
    ->expect(message->String.includes("capture a smaller element with the selector option"))
    ->Expect.toBe(true)
    t->expect(alternateMessage)->Expect.toBe(message)
  })

  test("keeps unrelated screenshot errors unchanged", t => {
    let message = "Canvas dimensions must be positive"
    t
    ->expect(Client__Tool__TakeScreenshot.captureErrorMessage(message))
    ->Expect.toBe(message)
  })
})
