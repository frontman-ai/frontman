module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

let parseUserMessageBlocks = (blocks: array<ContentBlock.t>): (
  array<Client__Message.UserContentPart.t>,
  array<Client__Message.MessageAnnotation.t>,
) => {
  let screenshotMap = Dict.make()
  blocks->Array.forEach(block =>
    switch block {
    | EmbeddedResource({_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})})
      if meta->Dict.has("annotation_screenshot") =>
      let parsed = S.parseOrThrow(
        JSON.Encode.object(meta),
        ~to=Client__Task__Types.screenshotMetaSchema,
      )
      switch parsed.annotationScreenshot {
      | true =>
        screenshotMap->Dict.set(
          parsed.annotationId,
          `data:${mimeType->Option.getOrThrow};base64,${blob}`,
        )
      | false => ()
      }
    | _ => ()
    }
  )

  let content = []
  let annotations = []
  blocks->Array.forEach(block =>
    switch block {
    | TextContent({text}) =>
      content->Array.push(Client__Message.UserContentPart.Text({text: text}))->ignore
    | EmbeddedResource({_meta: Some(meta), resource: TextResourceContents(_)})
      if meta->Dict.has("annotation") =>
      let parsed = S.parseOrThrow(
        JSON.Encode.object(meta),
        ~to=Client__Task__Types.annotationMetaSchema,
      )
      switch parsed.annotation {
      | true =>
        annotations
        ->Array.push(
          Client__Task__Types.annotationMetaToMessageAnnotation(
            parsed,
            ~screenshot=screenshotMap->Dict.get(parsed.annotationId),
          ),
        )
        ->ignore
      | false => ()
      }
    | EmbeddedResource({_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})}) =>
      switch meta->Dict.get("user_image")->Option.flatMap(JSON.Decode.bool) {
      | Some(true) =>
        let filename =
          meta->Dict.get("filename")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
        let mime = mimeType->Option.getOrThrow
        content
        ->Array.push(
          Client__Message.UserContentPart.Image({
            id: None,
            image: `data:${mime};base64,${blob}`,
            mediaType: Some(mime),
            name: Some(filename),
          }),
        )
        ->ignore
      | Some(false) | None => ()
      }
    | _ => ()
    }
  )
  (content, annotations)
}
