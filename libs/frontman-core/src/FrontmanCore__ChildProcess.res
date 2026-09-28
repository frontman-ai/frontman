module B = FrontmanBindings.ChildProcess

open B

type execOptions = B.execOptions
type execResult = B.execResult
type execError = B.execError

let defaultMaxBuffer = 50 * 1024 * 1024

let execPromise = (command: string, options: B.execOptions): Promise.t<
  result<B.execResult, B.execError>,
> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)
  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env
    B.nodeExec(command, {?cwd, ?env, maxBuffer, encoding: "utf8"}, (err, stdout, stderr) => {
      switch err->Nullable.toOption {
      | None => resolve(Ok({stdout, stderr}))
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
    })
  })
}

let spawnPromise = (command: string, args: array<string>, options: B.execOptions): Promise.t<
  result<B.execResult, B.execError>,
> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)

  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env

    try {
      let proc = B.spawn(command, args, {?cwd, ?env})

      let stdoutChunks: ref<array<B.buffer>> = ref([])
      let stderrChunks: ref<array<B.buffer>> = ref([])
      let stdoutLen = ref(0)
      let stderrLen = ref(0)

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

      proc
      ->B.processStdout
      ->B.onData(chunk => {
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

      proc
      ->B.processStderr
      ->B.onData(chunk => {
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

      proc->B.onProcess(
        #error(
          err => {
            guardedResolve(
              Error({
                code: None,
                stdout: decodeStdout(),
                stderr: decodeStderr(),
                message: JsError.message(err),
              }),
            )
          },
        ),
      )

      proc->B.onProcess(
        #close(
          nullableCode => {
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
          },
        ),
      )
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

let exec = async (command: string): result<B.execResult, B.execError> => {
  await execPromise(command, {maxBuffer: defaultMaxBuffer})
}

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

let spawnResult = async (command: string, args: array<string>, ~cwd: option<string>=?): result<
  B.execResult,
  B.execError,
> => {
  let options: B.execOptions = {
    ?cwd,
    maxBuffer: defaultMaxBuffer,
  }
  await spawnPromise(command, args, options)
}
