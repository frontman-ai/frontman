module Protocol = FrontmanAiFrontmanProtocol
module Tool = Protocol.FrontmanProtocol__Tool
module FileChange = Protocol.FrontmanProtocol__FileChange
module NodeBuffer = FrontmanBindings.NodeBuffer

let maxSnapshotBytes = 500 * 1024

let isBinary = (text: string): bool => text->String.indexOf("\u0000") >= 0

let make = (~path: string, ~status: FileChange.status, ~oldText: option<string>, ~currentText: option<string>, ~binary: bool): FileChange.envelope => {
  let bytes = oldText->Option.mapOr(0, NodeBuffer.byteLength) + currentText->Option.mapOr(0, NodeBuffer.byteLength)
  let unavailableReason = switch (binary, bytes > maxSnapshotBytes) {
  | (true, _) => Some(FileChange.Binary)
  | (_, true) => Some(FileChange.SizeLimited)
  | _ => None
  }
  {
    version: 1,
    path,
    status,
    oldPath: None,
    oldText: switch unavailableReason { | Some(_) => None | None => oldText },
    currentText: switch unavailableReason { | Some(_) => None | None => currentText },
    textAvailable: unavailableReason->Option.isNone,
    unavailableReason,
    wrote: true,
  }
}

let textResult = (~message: string, envelope: FileChange.envelope): Tool.MCP.CallToolResult.t => {
  let envelopeJson = envelope->S.decodeOrThrow(~from=FileChange.envelopeSchema, ~to=S.json->S.noValidation(true))
  let structuredContent = Dict.make()
  structuredContent->Dict.set(FileChange.reservedKey, envelopeJson)
  Tool.textResultWithStructured(message, structuredContent)
}
