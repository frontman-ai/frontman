import {existsSync, readFileSync} from "node:fs"
import {dirname, resolve} from "node:path"
import {fileURLToPath} from "node:url"
import {importRuntimeModule} from "./RuntimeImport.mjs"

export async function resolveSourceLocationInServer(sourceLocation, projectRoot) {
  if (!sourceLocation.file.startsWith("about://React/Server/")) return sourceLocation

  try {
    const generatedFile = fileURLToPath(
      sourceLocation.file.slice("about://React/Server/".length),
    )
    const adjacentMap = `${generatedFile}.map`
    const alternateMap = generatedFile.replace(/\.js$/, ".map")
    const mapFile = existsSync(adjacentMap)
      ? adjacentMap
      : existsSync(alternateMap)
        ? alternateMap
        : undefined
    if (!mapFile) return sourceLocation

    const sourceMapModule = "source-map"
    const {SourceMapConsumer} = await importRuntimeModule(sourceMapModule)
    const rawMap = JSON.parse(readFileSync(mapFile, "utf8"))
    const original = await SourceMapConsumer.with(rawMap, null, consumer =>
      consumer.originalPositionFor({line: sourceLocation.line, column: sourceLocation.column}),
    )
    if (original.source == null || original.line == null) return sourceLocation

    const projectPrefix = ["turbopack:///[project]/", "webpack:///[project]/"].find(prefix =>
      original.source.startsWith(prefix),
    )
    const webpackProjectSource = original.source.match(/^webpack:\/\/[^/]*\/(?:\.\/)?(.+)$/)
    const sourceFile = projectPrefix
      ? resolve(projectRoot, original.source.slice(projectPrefix.length))
      : webpackProjectSource
        ? resolve(projectRoot, webpackProjectSource[1])
        : original.source.startsWith("file://")
          ? fileURLToPath(original.source)
          : resolve(dirname(mapFile), original.source)

    return {
      ...sourceLocation,
      file: sourceFile.replace(/\\/g, "/"),
      line: original.line,
      column: original.column ?? sourceLocation.column,
    }
  } catch {
    return sourceLocation
  }
}
