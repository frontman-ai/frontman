import {readFile} from "node:fs/promises"

const bundle = JSON.parse(
  await readFile(new URL("../schemas/generated.json", import.meta.url), "utf8"),
)

export const generatedSchema = name => {
  if (!Object.hasOwn(bundle.$defs, name)) {
    throw new Error(`Unknown generated schema definition: ${name}`)
  }

  const pointer = name.replaceAll("~", "~0").replaceAll("/", "~1")
  return {$schema: bundle.$schema, $defs: bundle.$defs, $ref: `#/$defs/${pointer}`}
}
