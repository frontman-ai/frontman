import {relative, sep} from "node:path"
import {fileURLToPath} from "node:url"

import {rehypeContentFile} from "./rehype-content-file.mjs"

const registeredProcessors = new WeakSet()

function filesystemPath(value) {
  if (value instanceof URL) return fileURLToPath(value)
  return value || ""
}

function relativeContentPath(fileURL, projectRoot) {
  const path = relative(filesystemPath(projectRoot), fileURLToPath(fileURL))
  return sep === "/" ? path : path.split(sep).join("/")
}

export function createSatteriContentFilePlugin(options) {
  let inserted = false

  return {
    name: "frontman:content-file",
    element: {
      filter: [],
      visit(node, context) {
        if (inserted || !context.fileURL) return

        inserted = true
        context.insertBefore(node, {
          type: "element",
          tagName: "template",
          properties: {
            "data-frontman-content-file": relativeContentPath(context.fileURL, options.projectRoot),
          },
          children: [],
        })
      },
    },
  }
}

export function registerContentFilePlugin(processor, options) {
  if (!processor) return "legacy"
  if (registeredProcessors.has(processor)) return processor.name

  switch (processor.name) {
    case "satteri":
      processor.options ||= {}
      processor.options.hastPlugins ||= []
      processor.options.hastPlugins.push(() => createSatteriContentFilePlugin(options))
      registeredProcessors.add(processor)
      return "satteri"

    case "unified":
      processor.options ||= {}
      processor.options.rehypePlugins ||= []
      processor.options.rehypePlugins.push([rehypeContentFile, options])
      registeredProcessors.add(processor)
      return "unified"

    default:
      return "unsupported"
  }
}
