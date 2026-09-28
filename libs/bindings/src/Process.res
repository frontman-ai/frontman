@val external argv: array<string> = "process.argv"

@module("process")
external exit: int => unit = "exit"

@val @scope("process") external env: Dict.t<string> = "env"

@val @scope("process")
external cwd: unit => string = "cwd"

@val external __dirname: string = "__dirname"

@val
external setTimeout: (unit => unit, int) => float = "setTimeout"

@val @scope("process")
external on: (string, 'a => unit) => unit = "on"

type processError = {
  message: option<string>,
  stack: option<string>,
  name: string,
}

type rejectionReason
@get external getReasonMessage: rejectionReason => option<string> = "message"
@get external getReasonStack: rejectionReason => option<string> = "stack"
@scope("String") external stringFromReason: rejectionReason => string = "toString"
