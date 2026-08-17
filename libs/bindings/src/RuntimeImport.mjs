import {createRequire} from "node:module"
import {pathToFileURL} from "node:url"

const runtimeRequire = createRequire(import.meta.url)
const runtimeResolve = new Function("loader", "specifier", "return loader.resolve(specifier)")
const runtimeLoad = new Function("specifier", "return import(specifier)")

export const importRuntimeModule = async specifier => {
  const resolvedUrl = pathToFileURL(runtimeResolve(runtimeRequire, specifier)).href
  try {
    return await runtimeLoad(resolvedUrl)
  } catch (error) {
    if (error?.code !== "ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING") {
      throw error
    }
    return import(resolvedUrl)
  }
}
