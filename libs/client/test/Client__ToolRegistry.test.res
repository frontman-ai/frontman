open Vitest

module ToolRegistry = Client__ToolRegistry
module FrontmanClient = FrontmanAiFrontmanClient
module Relay = FrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanClient.FrontmanClient__MCP__Server

let toolNames = (framework): array<string> => {
  let registry = ToolRegistry.forFramework(framework)
  let relay = Relay.make(~baseUrl="http://localhost:3000")
  let server = ToolRegistry.registerAll(registry, MCPServer.make(~relay))

  server
  ->MCPServer.getToolsJson
  ->Array.filterMap(json =>
    json
    ->JSON.Decode.object
    ->Option.flatMap(obj => obj->Dict.get("name"))
    ->Option.flatMap(JSON.Decode.string)
  )
}

let toolAccessByName = (framework): Dict.t<string> => {
  let registry = ToolRegistry.forFramework(framework)
  let relay = Relay.make(~baseUrl="http://localhost:3000")
  let server = ToolRegistry.registerAll(registry, MCPServer.make(~relay))
  let accessByName = Dict.make()

  server
  ->MCPServer.getToolsJson
  ->Array.forEach(json => {
    switch json->JSON.Decode.object {
    | Some(obj) =>
      switch (
        obj->Dict.get("name")->Option.flatMap(JSON.Decode.string),
        obj->Dict.get("access")->Option.flatMap(JSON.Decode.string),
      ) {
      | (Some(name), Some(access)) => accessByName->Dict.set(name, access)
      | _ => ()
      }
    | None => ()
    }
  })

  accessByName
}

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
    let access = toolAccessByName(Client__RuntimeConfig.Nextjs)

    t->expect(access->Dict.get("take_screenshot"))->Expect.toEqual(Some("read"))
    t->expect(access->Dict.get("execute_js"))->Expect.toEqual(Some("read-write"))
    t->expect(access->Dict.get("set_device_mode"))->Expect.toEqual(Some("write"))
  })
})
