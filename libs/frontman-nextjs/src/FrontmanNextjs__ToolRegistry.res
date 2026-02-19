// Tool registry for Next.js - composes core tools with Next.js specific tools

module Core = FrontmanFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

// Re-export types from core
type tool = CoreRegistry.tool
type t = CoreRegistry.t

// Next.js specific tools
let nextjsTools: array<tool> = [
  module(FrontmanNextjs__Tool__GetRoutes),
  module(FrontmanNextjs__Tool__GetLogs),
]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(nextjsTools)
  ->CoreRegistry.replaceByName(module(FrontmanNextjs__Tool__EditFile))
}

// Re-export functions from core
let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
let addTools = CoreRegistry.addTools
let count = CoreRegistry.count
