module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

type tool = CoreRegistry.tool
type t = CoreRegistry.t

let nextjsTools: array<tool> = [
  module(FrontmanNextjs__Tool__GetRoutes),
  module(FrontmanNextjs__Tool__GetLogs),
]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(nextjsTools)
  ->CoreRegistry.replaceByName(module(FrontmanNextjs__Tool__EditFile))
  ->CoreRegistry.replaceByName(module(FrontmanNextjs__Tool__WriteFile))
}

let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
