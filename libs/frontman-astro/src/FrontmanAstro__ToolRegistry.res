module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

type tool = CoreRegistry.tool
type t = CoreRegistry.t

let astroTools: array<tool> = [
  module(FrontmanAstro__Tool__GetPages),
  module(FrontmanAstro__Tool__GetLogs),
  module(FrontmanAstro__Tool__GetContentCollections),
  module(FrontmanAstro__Tool__GetResolvedAstroConfig),
]

type loadContentApi = unit => promise<FrontmanAstro__Tool__GetContentCollections.contentApi>
type getAstroConfig = unit => option<FrontmanAstro__Tool__GetResolvedAstroConfig.captured>

let unavailableAstroConfig = (): option<FrontmanAstro__Tool__GetResolvedAstroConfig.captured> =>
  None

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(astroTools)
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithResolvedRoutes = (
  ~getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>,
  ~getAstroConfig: getAstroConfig=unavailableAstroConfig,
): t => {
  let resolvedRoutesTool = FrontmanAstro__Tool__GetResolvedRoutes.make(~getRoutes)
  let astroConfigTool = FrontmanAstro__Tool__GetResolvedAstroConfig.make(~getConfig=getAstroConfig)
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    resolvedRoutesTool,
    module(FrontmanAstro__Tool__GetLogs),
    module(FrontmanAstro__Tool__GetContentCollections),
    astroConfigTool,
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithAstroRuntime = (
  ~loadContentApi: loadContentApi,
  ~getAstroConfig: getAstroConfig=unavailableAstroConfig,
): t => {
  let contentCollectionsTool = FrontmanAstro__Tool__GetContentCollections.make(~loadContentApi)
  let astroConfigTool = FrontmanAstro__Tool__GetResolvedAstroConfig.make(~getConfig=getAstroConfig)

  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    module(FrontmanAstro__Tool__GetPages),
    module(FrontmanAstro__Tool__GetLogs),
    contentCollectionsTool,
    astroConfigTool,
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithResolvedRoutesAndAstroRuntime = (
  ~getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>,
  ~loadContentApi: loadContentApi,
  ~getAstroConfig: getAstroConfig=unavailableAstroConfig,
): t => {
  let resolvedRoutesTool = FrontmanAstro__Tool__GetResolvedRoutes.make(~getRoutes)
  let contentCollectionsTool = FrontmanAstro__Tool__GetContentCollections.make(~loadContentApi)
  let astroConfigTool = FrontmanAstro__Tool__GetResolvedAstroConfig.make(~getConfig=getAstroConfig)

  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    resolvedRoutesTool,
    module(FrontmanAstro__Tool__GetLogs),
    contentCollectionsTool,
    astroConfigTool,
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

@@live
let getToolByName = CoreRegistry.getToolByName
@@live
let getToolDefinitions = CoreRegistry.getToolDefinitions
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
