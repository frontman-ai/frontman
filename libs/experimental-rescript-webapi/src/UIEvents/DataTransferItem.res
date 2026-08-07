@send
external getAsString: (UiEventsTypes.dataTransferItem, string => unit) => unit = "getAsString"

@send
external getAsFile: UiEventsTypes.dataTransferItem => FileTypes.file = "getAsFile"

@send
external getAsFileNullable: UiEventsTypes.dataTransferItem => Null.t<FileTypes.file> = "getAsFile"

@send
external webkitGetAsEntry: UiEventsTypes.dataTransferItem => FileAndDirectoryEntriesTypes.fileSystemEntry =
  "webkitGetAsEntry"
