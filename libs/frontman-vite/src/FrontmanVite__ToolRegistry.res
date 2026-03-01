// Tool registry for Vite - composes core tools with Vite-specific tools

module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

// Re-export types from core
type tool = CoreRegistry.tool
type t = CoreRegistry.t

// Vite specific tools
let viteTools: array<tool> = [module(FrontmanVite__Tool__GetLogs)]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(viteTools)
  ->CoreRegistry.replaceByName(module(FrontmanVite__Tool__EditFile))
}

// Re-export functions from core
let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
let addTools = CoreRegistry.addTools
let count = CoreRegistry.count
