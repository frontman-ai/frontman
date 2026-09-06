module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

type tool = CoreRegistry.tool
type t = CoreRegistry.t

let nextjsTools: array<tool> = [
  module(FrontmanNextjs__Tool__Git),
  module(FrontmanNextjs__Tool__GetRoutes),
  module(FrontmanNextjs__Tool__GetLogs),
]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(nextjsTools)
  ->CoreRegistry.replaceByName(module(FrontmanNextjs__Tool__EditFile))
}

let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
