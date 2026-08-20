module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

type tool = CoreRegistry.tool
type t = CoreRegistry.t

let viteTools: array<tool> = [module(FrontmanVite__Tool__GetLogs)]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(viteTools)
  ->CoreRegistry.replaceByName(module(FrontmanVite__Tool__EditFile))
}

@@live
let getToolByName = CoreRegistry.getToolByName
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
