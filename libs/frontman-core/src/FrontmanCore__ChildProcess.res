// High-level child_process wrappers built on top of FrontmanBindings.ChildProcess
//
// Public API:
//   exec(command)              — run a shell command, returns result<execResult, execError>
//   execWithOptions(cmd, opts) — same, with cwd/env/maxBuffer options
//   spawnResult(cmd, args)     — run with args array (no shell), returns result<execResult, execError>

module B = FrontmanBindings.ChildProcess

// Bring record field names into scope so record literals resolve correctly
open B

// Re-export types so consumers don't need to reach into bindings
type execOptions = B.execOptions
type execResult = B.execResult
type execError = B.execError

// Default maxBuffer: 50MB
let defaultMaxBuffer = 50 * 1024 * 1024

// Wrap exec in a Promise that resolves with result — never rejects.
let execPromise = (
  command: string,
  options: B.execOptions,
): Promise.t<result<B.execResult, B.execError>> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)
  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env
    B.nodeExec(
      command,
      {?cwd, ?env, maxBuffer, encoding: "utf8"},
      (err, stdout, stderr) => {
        switch err->Nullable.toOption {
        | None =>
          resolve(Ok({stdout, stderr}))
        | Some(execErr) =>
          resolve(
            Error({
              code: execErr->B.execExceptionCode->Nullable.toOption,
              stdout,
              stderr,
              message: execErr->B.execExceptionMessage,
            }),
          )
        }
      },
    )
  })
}

// Promise-based spawn that captures stdout/stderr without a shell.
// Unlike exec (which passes a command string through /bin/sh), spawn sends
// the args array directly to the OS, so spaces in arguments are never
// re-interpreted as token separators.
//
// Resolves with result<execResult, execError> — never rejects.
let spawnPromise = (
  command: string,
  args: array<string>,
  options: B.execOptions,
): Promise.t<result<B.execResult, B.execError>> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)

  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env

    // Node's spawn() throws synchronously when cwd is invalid (ENOTDIR,
    // ENOENT).  Wrapping the entire body in try/catch ensures the error
    // flows through the result type instead of escaping as an unhandled
    // promise rejection that bypasses fallback chains.
    try {
      let proc = B.spawn(command, args, {?cwd, ?env})

      // Accumulate raw Buffer chunks to avoid corrupting multi-byte UTF-8
      // characters that span chunk boundaries. Decode to string only once
      // via Buffer.concat in the close/resolve handlers.
      let stdoutChunks: ref<array<B.buffer>> = ref([])
      let stderrChunks: ref<array<B.buffer>> = ref([])
      let stdoutLen = ref(0)
      let stderrLen = ref(0)

      // Guard against multiple resolve calls — after maxBuffer or error,
      // data handlers may still fire before the process dies. Without this
      // guard the refs keep growing past the limit.
      let resolved = ref(false)

      let decodeStdout = () => B.concatBuffers(stdoutChunks.contents)->B.bufferToStr
      let decodeStderr = () => B.concatBuffers(stderrChunks.contents)->B.bufferToStr

      let guardedResolve = value => {
        switch resolved.contents {
        | true => ()
        | false =>
          resolved := true
          resolve(value)
        }
      }

      proc->B.processStdout->B.onData(chunk => {
        switch resolved.contents {
        | true => ()
        | false =>
          stdoutChunks.contents->Array.push(chunk)
          stdoutLen := stdoutLen.contents + B.bufferByteLength(chunk)
          if stdoutLen.contents > maxBuffer {
            proc->B.kill(~signal="SIGTERM")->ignore
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

      proc->B.processStderr->B.onData(chunk => {
        switch resolved.contents {
        | true => ()
        | false =>
          stderrChunks.contents->Array.push(chunk)
          stderrLen := stderrLen.contents + B.bufferByteLength(chunk)
          if stderrLen.contents > maxBuffer {
            proc->B.kill(~signal="SIGTERM")->ignore
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

      proc->B.onProcess(#error(err => {
        guardedResolve(
          Error({
            code: None,
            stdout: decodeStdout(),
            stderr: decodeStderr(),
            message: JsError.message(err),
          }),
        )
      }))

      proc->B.onProcess(#close(nullableCode => {
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
    } catch {
    | exn =>
      let msg =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("spawn failed")
      resolve(Error({code: None, stdout: "", stderr: "", message: msg}))
    }
  })
}

// --- Public API ---

// Execute a shell command and return result or error
let exec = async (command: string): result<B.execResult, B.execError> => {
  await execPromise(command, {maxBuffer: defaultMaxBuffer})
}

// Execute a shell command with explicit options
let execWithOptions = async (command: string, options: B.execOptions): result<
  B.execResult,
  B.execError,
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
): result<B.execResult, B.execError> => {
  let options: B.execOptions = {
    ?cwd,
    maxBuffer: defaultMaxBuffer,
  }
  await spawnPromise(command, args, options)
}
