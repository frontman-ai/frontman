type role = | @as("assistant") Assistant | @as("user") User
type iconTheme = | @as("dark") Dark | @as("light") Light

type annotations = {
  audience: option<array<role>>,
  priority: option<float>,
  lastModified: option<string>,
}

type icon = {
  src: string,
  mimeType: option<string>,
  sizes: option<array<string>>,
  theme: option<iconTheme>,
}

let roleSchema = S.union([S.literal(Assistant), S.literal(User)])
let iconThemeSchema = S.union([S.literal(Dark), S.literal(Light)])
let prioritySchema = S.float->S.floatMin(0.0)->S.floatMax(1.0)

let annotationsSchema = S.object(s => {
  audience: s.field("audience", S.option(S.array(roleSchema))),
  priority: s.field("priority", S.option(prioritySchema)),
  lastModified: s.field("lastModified", S.option(S.string)),
})

let integerJsonSchema: JSONSchema.t = {
  type_: JSONSchema.Arrayable.single(#integer),
}

@scope("Number") @val
external isInteger: float => bool = "isInteger"

let integerSchema =
  S.float
  ->S.refine(isInteger, ~error="Resource size must be an integer")
  ->S.extendJSONSchema(integerJsonSchema)

let uriJsonSchema: JSONSchema.t = {
  type_: JSONSchema.Arrayable.single(#string),
  format: "uri",
}

let uriSchema = S.url->S.extendJSONSchema(uriJsonSchema)

let byteJsonSchema: JSONSchema.t = {
  type_: JSONSchema.Arrayable.single(#string),
  format: "byte",
}

let base64Pattern = /^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/
let byteSchema =
  S.string
  ->S.refine(value => base64Pattern->RegExp.test(value), ~error="Content data must be Base64")
  ->S.extendJSONSchema(byteJsonSchema)

let iconSchema = S.object(s => {
  src: s.field("src", uriSchema),
  mimeType: s.field("mimeType", S.option(S.string)),
  sizes: s.field("sizes", S.option(S.array(S.string))),
  theme: s.field("theme", S.option(iconThemeSchema)),
})

type textResourceContents = {
  uri: string,
  mimeType: option<string>,
  text: string,
  _meta: option<FrontmanProtocol__MCPMetadata.t>,
}

type blobResourceContents = {
  uri: string,
  mimeType: option<string>,
  blob: string,
  _meta: option<FrontmanProtocol__MCPMetadata.t>,
}

let textResourceContentsSchema = S.object(s => {
  uri: s.field("uri", uriSchema),
  mimeType: s.field("mimeType", S.option(S.string)),
  text: s.field("text", S.string),
  _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
})

let blobResourceContentsSchema = S.object(s => {
  uri: s.field("uri", uriSchema),
  mimeType: s.field("mimeType", S.option(S.string)),
  blob: s.field("blob", byteSchema),
  _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
})

type embeddedResourceResource =
  | TextResourceContents(textResourceContents)
  | BlobResourceContents(blobResourceContents)

let embeddedResourceResourceSchema = S.union([
  S.object(s => {
    TextResourceContents({
      uri: s.field("uri", uriSchema),
      mimeType: s.field("mimeType", S.option(S.string)),
      text: s.field("text", S.string),
      _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    })
  }),
  S.object(s => {
    BlobResourceContents({
      uri: s.field("uri", uriSchema),
      mimeType: s.field("mimeType", S.option(S.string)),
      blob: s.field("blob", byteSchema),
      _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    })
  }),
])

let jsonSchema = S.json->S.noValidation(true)
let embeddedResourceContentSchema =
  S.json
  ->S.transform(_ => {
    parser: resource => resource->S.parseOrThrow(~to=embeddedResourceResourceSchema),
    serializer: resource =>
      resource->S.decodeOrThrow(~from=embeddedResourceResourceSchema, ~to=jsonSchema),
  })
  ->S.extendJSONSchema(embeddedResourceResourceSchema->S.toJSONSchema)

type embeddedResource = {
  _meta: option<FrontmanProtocol__MCPMetadata.t>,
  annotations: option<annotations>,
  resource: embeddedResourceResource,
}

let embeddedResourceSchema = S.object(s => {
  s.tag("type", "resource")
  {
    resource: s.field("resource", embeddedResourceContentSchema),
    _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    annotations: s.field("annotations", S.option(annotationsSchema)),
  }
})

type mediaContent = {
  data: string,
  mimeType: string,
  _meta: option<FrontmanProtocol__MCPMetadata.t>,
  annotations: option<annotations>,
}

type t =
  | TextContent({
      text: string,
      _meta: option<FrontmanProtocol__MCPMetadata.t>,
      annotations: option<annotations>,
    })
  | ImageContent(mediaContent)
  | AudioContent(mediaContent)
  | ResourceLink({
      name: string,
      uri: string,
      title: option<string>,
      description: option<string>,
      mimeType: option<string>,
      size: option<float>,
      icons: option<array<icon>>,
      _meta: option<FrontmanProtocol__MCPMetadata.t>,
      annotations: option<annotations>,
    })
  | EmbeddedResource(embeddedResource)

let textContentSchema = S.object(s => {
  s.tag("type", "text")
  TextContent({
    text: s.field("text", S.string),
    _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    annotations: s.field("annotations", S.option(annotationsSchema)),
  })
})

let imageContentSchema = S.object(s => {
  s.tag("type", "image")
  ImageContent({
    data: s.field("data", byteSchema),
    mimeType: s.field("mimeType", S.string),
    _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    annotations: s.field("annotations", S.option(annotationsSchema)),
  })
})

let audioContentSchema = S.object(s => {
  s.tag("type", "audio")
  AudioContent({
    data: s.field("data", byteSchema),
    mimeType: s.field("mimeType", S.string),
    _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
    annotations: s.field("annotations", S.option(annotationsSchema)),
  })
})

let schema = S.union([
  textContentSchema,
  imageContentSchema,
  audioContentSchema,
  S.object(s => {
    s.tag("type", "resource_link")
    ResourceLink({
      name: s.field("name", S.string),
      uri: s.field("uri", uriSchema),
      title: s.field("title", S.option(S.string)),
      description: s.field("description", S.option(S.string)),
      mimeType: s.field("mimeType", S.option(S.string)),
      size: s.field("size", S.option(integerSchema)),
      icons: s.field("icons", S.option(S.array(iconSchema))),
      _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "resource")
    EmbeddedResource({
      resource: s.field("resource", embeddedResourceContentSchema),
      _meta: s.field("_meta", S.option(FrontmanProtocol__MCPMetadata.schema)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
])

let arraySchema =
  S.array(S.json)
  ->S.transform(_ => {
    parser: content => content->Array.map(S.parseOrThrow(_, ~to=schema)),
    serializer: content => content->Array.map(S.decodeOrThrow(_, ~from=schema, ~to=jsonSchema)),
  })
  ->S.extendJSONSchema(S.array(schema)->S.toJSONSchema)
