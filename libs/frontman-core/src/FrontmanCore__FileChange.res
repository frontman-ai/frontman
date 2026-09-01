module Protocol = FrontmanAiFrontmanProtocol
module Tool = Protocol.FrontmanProtocol__Tool
module FileChange = Protocol.FrontmanProtocol__FileChange
module NodeBuffer = FrontmanBindings.NodeBuffer

let maxSnapshotBytes = 500 * 1024

/** A tool's structured output paired with the change it made to the filesystem. */
type execution<'output> = {output: 'output, fileChange: FileChange.envelope}

let isBinary = (text: string): bool => text->String.indexOf("\u0000") >= 0

let make = (
  ~path: string,
  ~status: FileChange.status,
  ~oldText: option<string>,
  ~currentText: option<string>,
  ~binary: bool,
): FileChange.envelope => {
  let bytes =
    oldText->Option.mapOr(0, NodeBuffer.byteLength) +
      currentText->Option.mapOr(0, NodeBuffer.byteLength)
  let unavailableReason = switch (binary, bytes > maxSnapshotBytes) {
  | (true, _) => Some(FileChange.Binary)
  | (false, true) => Some(FileChange.SizeLimited)
  | (false, false) => None
  }
  let (oldText, currentText) = switch unavailableReason {
  | Some(_) => (None, None)
  | None => (oldText, currentText)
  }
  {
    path,
    status,
    oldPath: None,
    oldText,
    currentText,
    unavailableReason,
  }
}

let textResultWithFileChange = (
  ~message: string,
  ~output: 'output,
  ~outputSchema: S.t<'output>,
  envelope: FileChange.envelope,
): Tool.MCP.CallToolResult.t => {
  let structuredContent =
    output
    ->S.decodeOrThrow(~from=outputSchema, ~to=S.json->S.noValidation(true))
    ->JSON.Decode.object
    ->Option.getOrThrow
  let envelopeJson =
    envelope->S.decodeOrThrow(~from=FileChange.envelopeSchema, ~to=S.json->S.noValidation(true))
  structuredContent->Dict.set(FileChange.reservedKey, envelopeJson)
  Tool.MCP.CallToolResult.makeTextWithStructured(message, JSON.Encode.object(structuredContent))
}
