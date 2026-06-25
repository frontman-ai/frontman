open Vitest

module Tool = FrontmanAstro__Tool__GetContentCollections
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

let sourceRoot = "/tmp/frontman-astro-content-collections-test"
let projectRoot = sourceRoot ++ "/apps/site"
let ctx = {FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.projectRoot, sourceRoot}

let decodeToolResult = (result: MCP.CallToolResult.t): result<Tool.output, string> => {
  let json =
    result->S.decodeOrThrow(~from=MCP.callToolResultSchema, ~to=S.json->S.noValidation(true))
  let obj = json->JSON.Decode.object->Option.getOrThrow
  let isError = obj->Dict.get("isError")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
  let content = obj->Dict.get("content")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow
  let text = switch content->Array.get(0)->Option.flatMap(JSON.Decode.object) {
  | Some(block) => block->Dict.get("text")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  | None => ""
  }

  switch isError {
  | true => Error(text)
  | false =>
    try {
      Ok(text->JSON.parseOrThrow->S.parseOrThrow(~to=Tool.outputSchema))
    } catch {
    | _ => Error("Failed to decode tool result")
    }
  }
}

let blogEntry: Tool.runtimeEntry = {
  id: "hello-world",
  collection: "blog",
  data: `{"title":"Hello world","draft":false}`->JSON.parseOrThrow,
  body: ?Some("# Hello\n\nBody text."),
  filePath: ?Some("src/content/blog/hello-world.md"),
}

let secondEntry: Tool.runtimeEntry = {
  id: "second",
  collection: "blog",
  data: `{"title":"Second"}`->JSON.parseOrThrow,
  body: ?None,
  filePath: ?Some("src/content/blog/second.md"),
}

let loadContentApi = async (): Tool.contentApi => {
  getCollection: collection =>
    switch collection {
    | "blog" => Promise.resolve([blogEntry, secondEntry])
    | _ => Promise.resolve([])
    },
  getEntry: (collection, id) =>
    switch (collection, id) {
    | ("blog", "hello-world") => Promise.resolve(Some(blogEntry))
    | _ => Promise.resolve(None)
    },
}

let executeTool = async input => {
  let result = await Tool.executeWith(~loadContentApi, ctx, input)
  result->decodeToolResult
}

describe("get_content_collections", _t => {
  testAsync("queries collection entries through runtime API", async t => {
    let result = await executeTool({collection: "blog"})

    switch result {
    | Error(msg) => t->expect(msg)->Expect.toBe("")
    | Ok(output) =>
      t->expect(output.collection)->Expect.toBe("blog")
      t->expect(output.totalEntries)->Expect.toBe(2)
      t->expect(output.hasMore)->Expect.toBe(false)

      let entry = output.entries->Array.get(0)->Option.getOrThrow
      t->expect(entry.id)->Expect.toBe("hello-world")
      t->expect(entry.collection)->Expect.toBe("blog")
      t->expect(entry.body->Option.getOr("")->String.includes("Body text."))->Expect.toBe(true)

      let data = entry.data->JSON.Decode.object->Option.getOrThrow
      t
      ->expect(data->Dict.get("title")->Option.flatMap(JSON.Decode.string))
      ->Expect.toBe(Some("Hello world"))
    }
  })

  testAsync("queries individual entry through runtime API", async t => {
    let result = await executeTool({collection: "blog", entryId: ?Some("hello-world")})

    switch result {
    | Error(msg) => t->expect(msg)->Expect.toBe("")
    | Ok(output) =>
      t->expect(output.totalEntries)->Expect.toBe(1)
      let entry = output.entries->Array.get(0)->Option.getOrThrow
      t->expect(entry.id)->Expect.toBe("hello-world")
      t->expect(entry.filePath)->Expect.toBe(Some("apps/site/src/content/blog/hello-world.md"))
    }
  })

  testAsync("paginates runtime collection results", async t => {
    let result = await executeTool({collection: "blog", offset: ?Some(1), limit: ?Some(1)})

    switch result {
    | Error(msg) => t->expect(msg)->Expect.toBe("")
    | Ok(output) =>
      t->expect(output.totalEntries)->Expect.toBe(2)
      t->expect(output.entries->Array.length)->Expect.toBe(1)
      let entry = output.entries->Array.get(0)->Option.getOrThrow
      t->expect(entry.id)->Expect.toBe("second")
    }
  })

  testAsync("tool is registered", async t => {
    let registry = FrontmanAstro__ToolRegistry.make()
    t
    ->expect(FrontmanAstro__ToolRegistry.getToolByName(registry, "get_content_collections") != None)
    ->Expect.toBe(true)
  })
})
