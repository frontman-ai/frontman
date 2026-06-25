// Exposes Astro content collection entries through Astro's runtime API.

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module PathContext = FrontmanAiFrontmanCore.FrontmanCore__PathContext

let name = "get_content_collections"
let visibleToAgent = true

let description = `Queries Astro content collections through astro:content.

Parameters:
- collection (required): Collection name to query.
- entryId (optional): Entry id inside collection. When provided, uses getEntry().
- offset (optional): Entry pagination offset, default 0.
- limit (optional): Maximum entries to return, default 50.

Returns entries as Astro's runtime API sees them: id, collection, data, body, and filePath.`

@schema
type input = {
  collection: string,
  @live
  entryId?: string,
  @s.default(0) @live
  offset?: int,
  @s.default(50) @live
  limit?: int,
}

@schema
type contentEntry = {
  @live
  id: string,
  @live
  collection: string,
  @live
  data: JSON.t,
  @live
  body?: string,
  @live
  filePath?: string,
}

@schema
type output = {
  @live
  collection: string,
  @live
  totalEntries: int,
  @live
  offset: int,
  @live
  limit: int,
  @live
  hasMore: bool,
  @live
  entries: array<contentEntry>,
}

type runtimeEntry = {
  id: string,
  collection: string,
  data: JSON.t,
  body?: string,
  filePath?: string,
}

type contentApi = {
  getCollection: string => promise<array<runtimeEntry>>,
  getEntry: (string, string) => promise<option<runtimeEntry>>,
}

let unavailableContentApi = async (): contentApi =>
  failwith("Astro runtime content API unavailable. This tool only works inside astro dev.")

let jsonClone = (value: JSON.t): JSON.t => {
  switch JSON.stringifyAny(value) {
  | Some(text) => text->JSON.parseOrThrow
  | None => JSON.Encode.null
  }
}

let normalizeFilePath = (~ctx: Tool.serverExecutionContext, filePath: string): string => {
  let absolutePath = switch Path.isAbsolute(filePath) {
  | true => filePath
  | false => Path.join([ctx.projectRoot, filePath])
  }

  PathContext.toRelativePath(~sourceRoot=ctx.sourceRoot, ~absolutePath)
}

let toContentEntry = (~ctx: Tool.serverExecutionContext, entry: runtimeEntry): contentEntry => {
  id: entry.id,
  collection: entry.collection,
  data: entry.data->jsonClone,
  body: ?entry.body,
  filePath: ?(entry.filePath->Option.map(filePath => normalizeFilePath(~ctx, filePath))),
}

let executeWith = async (
  ~loadContentApi: unit => promise<contentApi>,
  ctx: Tool.serverExecutionContext,
  input: input,
): Tool.MCP.CallToolResult.t => {
  try {
    let offset = max(0, input.offset->Option.getOr(0))
    let limit = max(1, min(200, input.limit->Option.getOr(50)))
    let api = await loadContentApi()

    let allEntries = switch input.entryId {
    | Some(entryId) =>
      switch await api.getEntry(input.collection, entryId) {
      | Some(entry) => [entry]
      | None => []
      }
    | None => await api.getCollection(input.collection)
    }

    let selectedEntries = switch input.entryId {
    | Some(_) => allEntries
    | None => allEntries->Array.slice(~start=offset, ~end=offset + limit)
    }

    Tool.jsonResult(
      {
        collection: input.collection,
        totalEntries: allEntries->Array.length,
        offset: switch input.entryId {
        | Some(_) => 0
        | None => offset
        },
        limit,
        hasMore: switch input.entryId {
        | Some(_) => false
        | None => offset + limit < allEntries->Array.length
        },
        entries: selectedEntries->Array.map(entry => toContentEntry(~ctx, entry)),
      },
      outputSchema,
    )
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Tool.MCP.CallToolResult.makeError(`Failed to query Astro content collections: ${msg}`)
  }
}

let execute = (ctx: Tool.serverExecutionContext, input: input): promise<
  Tool.MCP.CallToolResult.t,
> => executeWith(~loadContentApi=unavailableContentApi, ctx, input)

let make = (~loadContentApi: unit => promise<contentApi>): module(Tool.ServerTool) => {
  module(
    {
      let name = name
      let visibleToAgent = visibleToAgent
      let description = description
      type input = input
      type output = output
      let inputSchema = inputSchema
      let outputSchema = outputSchema

      let execute = (ctx, input) => executeWith(~loadContentApi, ctx, input)
    }
  )
}
