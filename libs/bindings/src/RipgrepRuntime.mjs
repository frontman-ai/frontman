import {importRuntimeModule} from "./RuntimeImport.mjs"

const ripgrepModule = "@vscode/ripgrep"

export async function getRipgrepPath() {
  try {
    const {rgPath} = await importRuntimeModule(ripgrepModule)
    return rgPath
  } catch {
    return undefined
  }
}
