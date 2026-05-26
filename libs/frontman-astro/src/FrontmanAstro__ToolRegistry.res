// Tool registry for Astro - composes core tools with Astro specific tools

module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

// Re-export types from core
type tool = CoreRegistry.tool
type t = CoreRegistry.t

// Astro specific tools
let astroTools: array<tool> = [
  module(FrontmanAstro__Tool__GetPages),
  module(FrontmanAstro__Tool__GetLogs),
]

// Default: v4 filesystem-based page discovery
let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(astroTools)
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

// v5: resolved routes from astro:routes:resolved hook.
// Replaces the filesystem GetPages tool with one backed by hook data.
// Same tool name (get_client_pages) but richer data and accurate description.
let makeWithResolvedRoutes = (
  ~getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>,
): t => {
  let resolvedRoutesTool = FrontmanAstro__Tool__GetResolvedRoutes.make(~getRoutes)
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([resolvedRoutesTool, module(FrontmanAstro__Tool__GetLogs)])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

// Re-export functions from core
@@live
let getToolByName = CoreRegistry.getToolByName
@@live
let getToolDefinitions = CoreRegistry.getToolDefinitions
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
