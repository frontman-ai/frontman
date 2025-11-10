module Types = ContextLoader__Types
module Core = ContextLoader__Core
module IO = ContextLoader__IO
module Bindings = AskTheLlmBindings

type options = Types.options
type loadedContext = Types.loadedContext
type loadedFile = Types.loadedFile
type source = Types.source

let load = async (options: options): result<loadedContext, string> => {
  let cwd = Core.normalize(options.cwd, ~cwd=Bindings.Process.cwd())
  let root = switch options.root {
  | Some(r) => Core.normalize(r, ~cwd=Bindings.Process.cwd())
  | None => cwd
  }

  try {
    let localCandidates = Core.generateLocalCandidates(~cwd, ~root)
    let localPaths = await IO.discoverLocalFiles(localCandidates)

    let globalPaths = if Array.length(localPaths) == 0 {
      let globalCandidates = Core.globalFilePaths(options.globalConfigDir)
      await IO.discoverGlobalFiles(globalCandidates)
    } else {
      []
    }

    let customPaths = switch options.customPaths {
    | Some(paths) => paths->Array.map(p => Core.normalize(p, ~cwd))
    | None => []
    }

    let allPathsToLoad = Array.concat(Array.concat(localPaths, globalPaths), customPaths)
    let loadedData = await IO.loadFiles(allPathsToLoad)

    let localFiles = localPaths->Array.filterMap(localPath => {
      loadedData
      ->Array.find(((path, _)) => path == localPath)
      ->Option.map(((path, content)) =>
        Core.makeLoadedFile(path, content, Types.Local, ~discovered=true)
      )
    })

    let globalFiles = globalPaths->Array.filterMap(globalPath => {
      loadedData
      ->Array.find(((path, _)) => path == globalPath)
      ->Option.map(((path, content)) =>
        Core.makeLoadedFile(path, content, Types.Global, ~discovered=true)
      )
    })

    let customFiles = customPaths->Array.filterMap(customPath => {
      loadedData
      ->Array.find(((path, _)) => path == customPath)
      ->Option.map(((path, content)) =>
        Core.makeLoadedFile(path, content, Types.Custom, ~discovered=false)
      )
    })

    let allFiles = Array.concat(Array.concat(localFiles, globalFiles), customFiles)
    let filtered = Core.filterEmpty(allFiles)
    let result = Core.buildLoadedContext(filtered)

    Ok(result)
  } catch {
  | _ => Error("Context loading failed")
  }
}
