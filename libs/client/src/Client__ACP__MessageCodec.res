module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let parseUserMessageBlocks = (blocks: array<Types.contentBlock>): (
  array<Client__Message.UserContentPart.t>,
  array<Client__Message.MessageAnnotation.t>,
) => {
  let screenshotMap = Dict.make()
  blocks->Array.forEach(block =>
    switch block {
    | EmbeddedResource({_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})})
      if meta->JSON.Decode.object->Option.flatMap(d => d->Dict.get("annotation_screenshot")) !=
        None =>
      let parsed = S.parseOrThrow(meta, ~to=Client__Task__Types.screenshotMetaSchema)
      if parsed.annotationScreenshot {
        screenshotMap->Dict.set(
          parsed.annotationId,
          `data:${mimeType->Option.getOrThrow};base64,${blob}`,
        )
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
      if meta->JSON.Decode.object->Option.flatMap(d => d->Dict.get("annotation")) != None =>
      let parsed = S.parseOrThrow(meta, ~to=Client__Task__Types.annotationMetaSchema)
      if parsed.annotation {
        annotations
        ->Array.push(
          Client__Task__Types.annotationMetaToMessageAnnotation(
            parsed,
            ~screenshot=screenshotMap->Dict.get(parsed.annotationId),
          ),
        )
        ->ignore
      }
    | EmbeddedResource({_meta: Some(meta), resource: BlobResourceContents({blob, mimeType})}) =>
      switch meta->JSON.Decode.object {
      | Some(d) if d->Dict.get("user_image") == Some(JSON.Encode.bool(true)) =>
        let filename =
          d->Dict.get("filename")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
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
      | _ => ()
      }
    | _ => ()
    }
  )
  (content, annotations)
}
