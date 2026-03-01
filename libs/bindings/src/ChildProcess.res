// Bindings for Node.js child_process module
//
// Pure bindings — types and @module externals only.
// For the high-level exec/spawn API, see FrontmanCore.ChildProcess.

// Exec options and result types
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

// Node's ExecException — the error object passed to exec's callback on failure.
type execException
@get external execExceptionCode: execException => Nullable.t<int> = "code"
@get external execExceptionMessage: execException => string = "message"

// exec's internal options include encoding to force string output
type execInternalOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  maxBuffer?: int,
  encoding: string,
}

// Node's exec with callback: (error, stdout, stderr) => void
// With encoding: "utf8", stdout/stderr are always strings.
@module("node:child_process")
external nodeExec: (
  string,
  execInternalOptions,
  (Nullable.t<execException>, string, string) => unit,
) => unit = "exec"

// --- Spawn bindings ---

// Opaque child process handle returned by spawn
type childProcess

type spawnOptions = {
  cwd?: string,
  env?: Dict.t<string>,
}

@module("node:child_process")
external spawn: (string, array<string>, spawnOptions) => childProcess = "spawn"

// Process-level stdout/stderr are readable streams
@get external processStdout: childProcess => NodeStreams.readable = "stdout"
@get external processStderr: childProcess => NodeStreams.readable = "stderr"

@send external kill: (childProcess, ~signal: string=?) => bool = "kill"

// Process-level events: close(code), error(err)
@send
external onProcess: (
  childProcess,
  @string
  [
    | #close(Nullable.t<int> => unit)
    | #error(JsError.t => unit)
  ],
) => unit = "on"

// Stream data event — receives a Buffer chunk
type buffer
@send external bufferToStr: (buffer, @as("utf8") _) => string = "toString"
@get external bufferByteLength: buffer => int = "byteLength"
@module("node:buffer") @scope("Buffer")
external concatBuffers: array<buffer> => buffer = "concat"

@send
external onData: (NodeStreams.readable, @as("data") _, buffer => unit) => unit = "on"
