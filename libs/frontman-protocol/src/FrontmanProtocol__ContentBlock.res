let prioritySchema =
  S.float
  ->S.refine(value => value >= 0. && value <= 1., ~error="Expected number between 0 and 1")
  ->S.extendJSONSchema({minimum: 0., maximum: 1.})
let audienceSchema = S.union([S.literal("user"), S.literal("assistant")])

@schema
type annotations = {
  audience: option<array<@s.matches(audienceSchema) string>>,
  priority: option<@s.matches(prioritySchema) float>,
  lastModified: option<string>,
}

@schema
type textResourceContents = {uri: string, mimeType: option<string>, text: string, _meta?: JSON.t}

@schema
type blobResourceContents = {uri: string, mimeType: option<string>, blob: string, _meta?: JSON.t}

type embeddedResourceResource =
  | TextResourceContents(textResourceContents)
  | BlobResourceContents(blobResourceContents)

let embeddedResourceResourceSchema = S.union([
  S.object(s => {
    TextResourceContents({
      uri: s.field("uri", S.string),
      mimeType: s.field("mimeType", S.option(S.string)),
      text: s.field("text", S.string),
      _meta: ?s.field("_meta", S.option(S.json)),
    })
  }),
  S.object(s => {
    BlobResourceContents({
      uri: s.field("uri", S.string),
      mimeType: s.field("mimeType", S.option(S.string)),
      blob: s.field("blob", S.string),
      _meta: ?s.field("_meta", S.option(S.json)),
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

@schema
type embeddedResource = {
  _meta: option<JSON.t>,
  annotations: option<annotations>,
  resource: embeddedResourceResource,
}

type meta = option<JSON.t>
type mediaContent = {data: string, mimeType: string, _meta: meta, annotations: option<annotations>}

type t =
  | TextContent({text: string, _meta: option<JSON.t>, annotations: option<annotations>})
  | ImageContent(mediaContent)
  | AudioContent(mediaContent)
  | ResourceLink({
      name: string,
      title: option<string>,
      uri: string,
      description: option<string>,
      mimeType: option<string>,
      size: option<int>,
      _meta: option<JSON.t>,
      annotations: option<annotations>,
    })
  | EmbeddedResource(embeddedResource)

let schema = S.union([
  S.object(s => {
    s.tag("type", "text")
    TextContent({
      text: s.field("text", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "image")
    ImageContent({
      data: s.field("data", S.string),
      mimeType: s.field("mimeType", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "audio")
    AudioContent({
      data: s.field("data", S.string),
      mimeType: s.field("mimeType", S.string),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "resource_link")
    ResourceLink({
      name: s.field("name", S.string),
      title: s.field("title", S.option(S.string)),
      uri: s.field("uri", S.string),
      description: s.field("description", S.option(S.string)),
      mimeType: s.field("mimeType", S.option(S.string)),
      size: s.field("size", S.option(S.int)),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
  S.object(s => {
    s.tag("type", "resource")
    EmbeddedResource({
      resource: s.field("resource", embeddedResourceContentSchema),
      _meta: s.field("_meta", S.option(S.json)),
      annotations: s.field("annotations", S.option(annotationsSchema)),
    })
  }),
])

let arraySchema = S.array(S.json)->S.transform(_ => {
  parser: content => content->Array.map(S.parseOrThrow(_, ~to=schema)),
  serializer: content => content->Array.map(S.decodeOrThrow(_, ~from=schema, ~to=jsonSchema)),
})
