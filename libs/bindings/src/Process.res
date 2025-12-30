// Process globals
@val external argv: array<string> = "process.argv"

@module("process")
external exit: int => unit = "exit"

// Process environment variables
@val @scope("process") external env: Dict.t<string> = "env"

// Current working directory
@val @scope("process")
external cwd: unit => string = "cwd"

// Node.js __dirname global
@val external __dirname: string = "__dirname"

// Timeout function
@val
external setTimeout: (unit => unit, int) => float = "setTimeout"

// Process event handling
@val @scope("process")
external on: (string, 'a => unit) => unit = "on"

// Error/rejection types for event handlers
type processError = {
  message: option<string>,
  stack: option<string>,
  name: string,
}

type rejectionReason
@get external getReasonMessage: rejectionReason => option<string> = "message"
@get external getReasonStack: rejectionReason => option<string> = "stack"
@scope("String") external stringFromReason: rejectionReason => string = "toString"
