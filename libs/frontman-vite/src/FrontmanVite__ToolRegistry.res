// Tool registry for Vite - composes core tools (no Vite-specific tools for now)

module Core = FrontmanFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

// Re-export types from core
type tool = CoreRegistry.tool
type t = CoreRegistry.t

let make = (): t => {
  CoreRegistry.coreTools()
}

// Re-export functions from core
let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
let addTools = CoreRegistry.addTools
let count = CoreRegistry.count
