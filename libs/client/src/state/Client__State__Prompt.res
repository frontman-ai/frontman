module Message = Client__State__Types.Message
module TaskReducer = Client__Task__Reducer
module Selectors = Client__State__Selectors
type state = Client__State__Types.state

let buildAttachmentContentBlocks = (attachments: array<Client__Message.fileAttachmentData>): array<
  Client__State__Types.ContentBlock.t,
> => {
  attachments->Array.map(att => {
    let base64Data = switch att.dataUrl->String.indexOf(";base64,") {
    | -1 => att.dataUrl
    | idx => att.dataUrl->String.slice(~start=idx + 8, ~end=String.length(att.dataUrl))
    }

    let metaObj = Dict.make()
    metaObj->Dict.set("user_image", JSON.Encode.bool(true))
    metaObj->Dict.set("filename", JSON.Encode.string(att.filename))
    let meta = JSON.Encode.object(metaObj)

    Client__State__Types.ContentBlock.EmbeddedResource({
      resource: Client__State__Types.ContentBlock.BlobResourceContents({
        uri: `attachment://${att.id}/${att.filename}`,
        mimeType: Some(att.mediaType),
        blob: base64Data,
      }),
      _meta: Some(meta),
      annotations: None,
    })
  })
}

let buildPrompt = (state: state, ~messageId, ~attachments, ~annotations, ~task, ~agentId) => {
  let runtimeConfig = Client__RuntimeConfig.read()
  let pageContextBlocks = Client__State__Types.taskToPageContextBlocks(
    task,
    ~isAstro=runtimeConfig.framework == Astro,
  )

  let annotationBlocks = Client__State__Types.messageAnnotationsToContentBlocks(annotations)

  let attachmentBlocks = buildAttachmentContentBlocks(attachments)
  let additionalBlocks =
    Array.concat(pageContextBlocks, annotationBlocks)->Array.concat(attachmentBlocks)

  let baseMeta = Client__RuntimeConfig.toMeta(runtimeConfig)
  let metadata = baseMeta->JSON.Decode.object->Option.getOrThrow->Dict.copy
  state.selectedModelValue->Option.forEach(modelValue =>
    metadata->Dict.set("model", JSON.Encode.string(modelValue))
  )
  metadata->Dict.set(
    "frontman.dev/messageId",
    JSON.Encode.string(Message.UserMessageId.toString(messageId)),
  )
  metadata->Dict.set("agent", JSON.Encode.string(agentId))
  (additionalBlocks, Some(JSON.Encode.object(metadata)))
}

let validatePrompt = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol.validatePrompt

let validateSubmission = (state: state, submission: Client__State__Types.submission) => {
  let {id: messageId, content, annotations, agentId} = submission
  let text = TaskReducer.extractTextFromUserContent(content)
  let attachments = TaskReducer.extractAttachmentsFromUserContent(content)
  let (additionalBlocks, _meta) = buildPrompt(
    state,
    ~messageId,
    ~attachments,
    ~annotations,
    ~task=Selectors.currentTask(state),
    ~agentId,
  )
  switch state.selectedModelValue {
  | None => Error("Select a model before sending.")
  | Some(_) => validatePrompt(~text, ~additionalBlocks, ~_meta)
  }
}
