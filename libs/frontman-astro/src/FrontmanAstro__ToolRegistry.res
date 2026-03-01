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

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(astroTools)
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

// Re-export functions from core
let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
let addTools = CoreRegistry.addTools
let count = CoreRegistry.count
