type execOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  maxBuffer?: int,
}

type execResult = {
  stdout: string,
  stderr: string,
}

type execError = {
  code: option<int>,
  stdout: string,
  stderr: string,
  message: string,
}

type execException
@get external execExceptionCode: execException => Nullable.t<int> = "code"
@get external execExceptionMessage: execException => string = "message"

type execInternalOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  maxBuffer?: int,
  encoding: string,
}

@module("node:child_process")
external nodeExec: (
  string,
  execInternalOptions,
  (Nullable.t<execException>, string, string) => unit,
) => unit = "exec"

type childProcess

type spawnOptions = {
  cwd?: string,
  env?: Dict.t<string>,
}

@module("node:child_process")
external spawn: (string, array<string>, spawnOptions) => childProcess = "spawn"

@get external processStdout: childProcess => NodeStreams.readable = "stdout"
@get external processStderr: childProcess => NodeStreams.readable = "stderr"

@send external kill: (childProcess, ~signal: string=?) => bool = "kill"

@send
external onProcess: (
  childProcess,
  @string
  [
    | #close(Nullable.t<int> => unit)
    | #error(JsError.t => unit)
  ],
) => unit = "on"

type buffer
@send external bufferToStr: (buffer, @as("utf8") _) => string = "toString"
@get external bufferByteLength: buffer => int = "byteLength"
@module("node:buffer") @scope("Buffer")
external concatBuffers: array<buffer> => buffer = "concat"

@send
external onData: (NodeStreams.readable, @as("data") _, buffer => unit) => unit = "on"
