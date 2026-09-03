module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Bindings = FrontmanBindings.Astro

let name = "get_resolved_astro_config"
let access = Tool.Read

let description = `Returns Astro's resolved project config captured from astro:config:done.

Parameters: None

Use before changing routing, SSR/static behavior, adapters, i18n, images,
Markdown/MDX, redirects, sessions, security, or deployment behavior.`

@schema
type input = {
  @live
  placeholder?: bool,
}

@schema
type output = {
  @live
  astroVersion: string,
  @live
  buildOutput: string,
  @live
  output?: string,
  @live
  adapter?: string,
  @live
  integrations: array<string>,
  @live
  site?: string,
  @live
  base: string,
  @live
  trailingSlash: string,
  @live
  redirects?: JSON.t,
  @live
  i18n?: JSON.t,
  @live
  image?: JSON.t,
  @live
  markdown?: JSON.t,
  @live
  security?: JSON.t,
  @live
  session?: JSON.t,
  @live
  server?: JSON.t,
}

type captured = {
  astroVersion: string,
  buildOutput: string,
  config: Bindings.astroConfig,
}

@module("./resolved-astro-config.mjs")
external sanitizeResolvedAstroConfig: captured => output = "sanitizeResolvedAstroConfig"

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

let executeWith = async (~getConfig: unit => option<captured>, _ctx, _input) => {
  switch getConfig() {
  | Some(config) => Tool.structuredResult(config->sanitizeResolvedAstroConfig, outputSchema)
  | None => Tool.MCP.CallToolResult.makeError("Astro config has not been captured yet")
  }
}

let execute = (ctx, input) => executeWith(~getConfig=() => None, ctx, input)

let make = (~getConfig: unit => option<captured>): module(Tool.ServerTool) => {
  module(
    {
      let name = name
      let access = access
      let visibleToAgent = visibleToAgent
      let description = description
      type input = input
      let inputSchema = inputSchema
      let outputJsonSchema = outputJsonSchema

      let execute = (ctx, input) => executeWith(~getConfig, ctx, input)
    }
  )
}
