include EventTarget.Impl({type t = ClipboardTypes.clipboard})

@send
external read: ClipboardTypes.clipboard => promise<array<ClipboardTypes.clipboardItem>> = "read"

@send
external readText: ClipboardTypes.clipboard => promise<string> = "readText"

@send
external write: (ClipboardTypes.clipboard, array<ClipboardTypes.clipboardItem>) => promise<unit> =
  "write"

@send
external writeText: (ClipboardTypes.clipboard, string) => promise<unit> = "writeText"

module ClipboardItem = ClipboardItem
module Types = ClipboardTypes
