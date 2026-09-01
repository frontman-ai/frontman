module Core = FrontmanAiFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

type tool = CoreRegistry.tool
type t = CoreRegistry.t

let astroTools: array<tool> = [
  module(FrontmanAstro__Tool__GetPages),
  module(FrontmanAstro__Tool__GetLogs),
  module(FrontmanAstro__Tool__GetContentCollections),
]

type loadContentApi = unit => promise<FrontmanAstro__Tool__GetContentCollections.contentApi>

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(astroTools)
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithResolvedRoutes = (
  ~getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>,
): t => {
  let resolvedRoutesTool = FrontmanAstro__Tool__GetResolvedRoutes.make(~getRoutes)
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    resolvedRoutesTool,
    module(FrontmanAstro__Tool__GetLogs),
    module(FrontmanAstro__Tool__GetContentCollections),
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithAstroRuntime = (~loadContentApi: loadContentApi): t => {
  let contentCollectionsTool = FrontmanAstro__Tool__GetContentCollections.make(~loadContentApi)

  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    module(FrontmanAstro__Tool__GetPages),
    module(FrontmanAstro__Tool__GetLogs),
    contentCollectionsTool,
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

let makeWithResolvedRoutesAndAstroRuntime = (
  ~getRoutes: unit => array<FrontmanBindings.Astro.integrationResolvedRoute>,
  ~loadContentApi: loadContentApi,
): t => {
  let resolvedRoutesTool = FrontmanAstro__Tool__GetResolvedRoutes.make(~getRoutes)
  let contentCollectionsTool = FrontmanAstro__Tool__GetContentCollections.make(~loadContentApi)

  CoreRegistry.coreTools()
  ->CoreRegistry.addTools([
    resolvedRoutesTool,
    module(FrontmanAstro__Tool__GetLogs),
    contentCollectionsTool,
  ])
  ->CoreRegistry.replaceByName(module(FrontmanAstro__Tool__EditFile))
}

@@live
let getToolByName = CoreRegistry.getToolByName
@@live
let addTools = CoreRegistry.addTools
@@live
let count = CoreRegistry.count
