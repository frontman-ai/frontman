type fd
type stats

module Promises = {
  @module("fs") @scope("promises")
  external readFile: (string, @as("utf8") _) => promise<string> = "readFile"

  @module("fs") @scope("promises")
  external readFileBuffer: string => promise<ArrayBuffer.t> = "readFile"

  @module("fs") @scope("promises")
  external writeFile: (string, string, @as("utf8") _) => promise<unit> = "writeFile"

  @module("fs") @scope("promises")
  external writeFileBuffer: (string, NodeBuffer.t) => promise<unit> = "writeFile"

  @module("fs") @scope("promises")
  external readdir: string => promise<array<string>> = "readdir"

  @module("fs") @scope("promises")
  external stat: string => promise<stats> = "stat"

  @module("fs") @scope("promises")
  external lstat: string => promise<stats> = "lstat"

  @module("fs") @scope("promises")
  external unlink: string => promise<unit> = "unlink"

  @module("fs") @scope("promises")
  external access: string => promise<unit> = "access"

  @module("fs") @scope("promises")
  external accessWithMode: (string, int) => promise<unit> = "access"

  type mkdirOptions = {recursive: bool}
  @module("fs") @scope("promises")
  external mkdir: (string, mkdirOptions) => promise<option<string>> = "mkdir"

  module Constants = {
    @module("fs") @scope(("promises", "constants")) external f_OK: int = "F_OK"
    @module("fs") @scope(("promises", "constants")) external r_OK: int = "R_OK"
    @module("fs") @scope(("promises", "constants")) external w_OK: int = "W_OK"
    @module("fs") @scope(("promises", "constants")) external x_OK: int = "X_OK"
  }
}

@module("fs")
external readFileSync: (string, @as("utf8") _) => string = "readFileSync"

@send external isFile: stats => bool = "isFile"
@send external isDirectory: stats => bool = "isDirectory"
@send external isSymbolicLink: stats => bool = "isSymbolicLink"
@get external size: stats => float = "size"
@get external mtimeMs: stats => float = "mtimeMs"
