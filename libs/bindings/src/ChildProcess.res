// Bindings for Node.js child_process module
//
// Public API:
//   exec(command)           — run a shell command, returns result<execResult, execError>
//   execWithOptions(cmd, opts) — same, with cwd/env/maxBuffer options
//   spawnResult(cmd, args)  — run with args array (no shell), returns result<execResult, execError>

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

// Default maxBuffer: 50MB
let defaultMaxBuffer = 50 * 1024 * 1024

// --- Typed exec bindings (internal) ---

// Node's ExecException — the error object passed to exec's callback on failure.
// We only read the fields we need; everything else is ignored.
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

// Wrap exec in a Promise that resolves with result — never rejects.
let execPromise = (
  command: string,
  options: execOptions,
): Promise.t<result<execResult, execError>> => {
  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env
    let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)
    nodeExec(
      command,
      {?cwd, ?env, maxBuffer, encoding: "utf8"},
      (err, stdout, stderr) => {
        switch err->Nullable.toOption {
        | None =>
          resolve(Ok({stdout, stderr}))
        | Some(execErr) =>
          resolve(
            Error({
              code: execErr->execExceptionCode->Nullable.toOption,
              stdout,
              stderr,
              message: execErr->execExceptionMessage,
            }),
          )
        }
      },
    )
  })
}

// --- Typed spawn bindings (internal) ---

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

// --- spawnPromise in pure ReScript ---

// Promise-based spawn that captures stdout/stderr without a shell.
// Unlike exec (which passes a command string through /bin/sh), spawn sends
// the args array directly to the OS, so spaces in arguments are never
// re-interpreted as token separators.
//
// Resolves with result<execResult, execError> — never rejects.
let spawnPromise = (
  command: string,
  args: array<string>,
  options: execOptions,
): Promise.t<result<execResult, execError>> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)

  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env
    let proc = spawn(command, args, {?cwd, ?env})

    // Accumulate raw Buffer chunks to avoid corrupting multi-byte UTF-8
    // characters that span chunk boundaries. Decode to string only once
    // via Buffer.concat in the close/resolve handlers.
    let stdoutChunks: ref<array<buffer>> = ref([])
    let stderrChunks: ref<array<buffer>> = ref([])
    let stdoutLen = ref(0)
    let stderrLen = ref(0)

    // Guard against multiple resolve calls — after maxBuffer or error,
    // data handlers may still fire before the process dies. Without this
    // guard the refs keep growing past the limit.
    let resolved = ref(false)

    let decodeStdout = () => concatBuffers(stdoutChunks.contents)->bufferToStr
    let decodeStderr = () => concatBuffers(stderrChunks.contents)->bufferToStr

    let guardedResolve = value => {
      switch resolved.contents {
      | true => ()
      | false =>
        resolved := true
        resolve(value)
      }
    }

    proc->processStdout->onData(chunk => {
      switch resolved.contents {
      | true => ()
      | false =>
        stdoutChunks.contents->Array.push(chunk)
        stdoutLen := stdoutLen.contents + bufferByteLength(chunk)
        if stdoutLen.contents > maxBuffer {
          proc->kill(~signal="SIGTERM")->ignore
          guardedResolve(
            Error({
              code: None,
              stdout: decodeStdout(),
              stderr: decodeStderr(),
              message: "stdout maxBuffer exceeded",
            }),
          )
        }
      }
    })

    proc->processStderr->onData(chunk => {
      switch resolved.contents {
      | true => ()
      | false =>
        stderrChunks.contents->Array.push(chunk)
        stderrLen := stderrLen.contents + bufferByteLength(chunk)
        if stderrLen.contents > maxBuffer {
          proc->kill(~signal="SIGTERM")->ignore
          guardedResolve(
            Error({
              code: None,
              stdout: decodeStdout(),
              stderr: decodeStderr(),
              message: "stderr maxBuffer exceeded",
            }),
          )
        }
      }
    })

    proc->onProcess(#error(err => {
      guardedResolve(
        Error({
          code: None,
          stdout: decodeStdout(),
          stderr: decodeStderr(),
          message: JsError.message(err),
        }),
      )
    }))

    proc->onProcess(#close(nullableCode => {
      let code = nullableCode->Nullable.toOption
      switch code {
      | Some(0) =>
        guardedResolve(
          Ok({
            stdout: decodeStdout(),
            stderr: decodeStderr(),
          }),
        )
      | _ =>
        let codeStr = switch code {
        | Some(c) => Int.toString(c)
        | None => "null"
        }
        guardedResolve(
          Error({
            code,
            stdout: decodeStdout(),
            stderr: decodeStderr(),
            message: `Process exited with code ${codeStr}`,
          }),
        )
      }
    }))
  })
}

// --- Public API ---

// Execute a shell command and return result or error
let exec = async (command: string): result<execResult, execError> => {
  await execPromise(command, {maxBuffer: defaultMaxBuffer})
}

// Execute a shell command with explicit options
let execWithOptions = async (command: string, options: execOptions): result<
  execResult,
  execError,
> => {
  let optionsWithDefaults = {
    ...options,
    maxBuffer: options.maxBuffer->Option.getOr(defaultMaxBuffer),
  }
  await execPromise(command, optionsWithDefaults)
}

// Spawn a process with an args array (no shell) and return result or error.
// This is the preferred way to run subprocesses when you have structured arguments,
// since it avoids shell parsing issues with spaces and special characters.
let spawnResult = async (
  command: string,
  args: array<string>,
  ~cwd: option<string>=?,
): result<execResult, execError> => {
  let options: execOptions = {
    ?cwd,
    maxBuffer: defaultMaxBuffer,
  }
  await spawnPromise(command, args, options)
}
