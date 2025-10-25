// Node.js fs module bindings

type fd
type stats

module Promises = {
  @module("fs") @scope("promises")
  external readFile: (string, @as("utf8") _) => promise<string> = "readFile"

  @module("fs") @scope("promises")
  external writeFile: (string, string, @as("utf8") _) => promise<unit> = "writeFile"

  @module("fs") @scope("promises")
  external readdir: string => promise<array<string>> = "readdir"

  @module("fs") @scope("promises")
  external stat: string => promise<stats> = "stat"

  // Access with default mode (F_OK)
  @module("fs") @scope("promises")
  external access: string => promise<unit> = "access"

  // Access with specific mode
  @module("fs") @scope("promises")
  external accessWithMode: (string, int) => promise<unit> = "access"

  // Access mode constants (from fs.promises.constants)
  module Constants = {
    @module("fs") @scope(("promises", "constants")) external f_OK: int = "F_OK"
    @module("fs") @scope(("promises", "constants")) external r_OK: int = "R_OK"
    @module("fs") @scope(("promises", "constants")) external w_OK: int = "W_OK"
    @module("fs") @scope(("promises", "constants")) external x_OK: int = "X_OK"
  }
}

@send external isFile: stats => bool = "isFile"
@send external isDirectory: stats => bool = "isDirectory"
