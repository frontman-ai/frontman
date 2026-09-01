module B = FrontmanBindings.ChildProcess

type execOptions = B.execOptions
type execResult = B.execResult
type execError = B.execError

let abortedError = (): B.execError => {
  code: None,
  B.stdout: "",
  stderr: "",
  message: "Process aborted",
}

let defaultMaxBuffer = 50 * 1024 * 1024

let execPromise = (
  command: string,
  options: B.execOptions,
  ~signal: option<WebAPI.EventTypes.abortSignal>=?,
): Promise.t<result<B.execResult, B.execError>> => {
  let maxBuffer = options.maxBuffer->Option.getOr(defaultMaxBuffer)
  Promise.make((resolve, _reject) => {
    let cwd = options.cwd
    let env = options.env
    let resolved = ref(false)
    let aborted = ref(false)
    let proc = ref(None)
    let abortNow = () => {
      aborted := true
      switch proc.contents {
      | Some(proc) => proc->B.kill(~signal="SIGTERM")->ignore
      | None => ()
      }
    }
    let onAbort = _event => abortNow()
    signal->Option.forEach(signal => signal->WebAPI.AbortSignal.addEventListener(Abort, onAbort))
    let child = B.nodeExecProcess(command, {?cwd, ?env, maxBuffer, encoding: "utf8"}, (
      err,
      stdout,
      stderr,
    ) => {
      signal->Option.forEach(
        signal => signal->WebAPI.AbortSignal.removeEventListener(Abort, onAbort),
      )
      switch resolved.contents {
      | true => ()
      | false =>
        resolved := true
        switch aborted.contents {
        | true => resolve(Error(abortedError()))
        | false =>
          switch err->Nullable.toOption {
          | None => resolve(Ok({B.stdout, stderr}))
          | Some(execErr) =>
            resolve(
              Error({
                code: execErr->B.execExceptionCode->Nullable.toOption,
                B.stdout,
                stderr,
                message: execErr->B.execExceptionMessage,
              }),
            )
          }
        }
      }
    })
    proc := Some(child)
    switch signal {
    | Some({aborted: true}) => abortNow()
    | Some(_) | None => ()
    }
  })
}

let spawnPromise = (
  command: string,
  args: array<string>,
  options: B.execOptions,
  ~signal: option<WebAPI.EventTypes.abortSignal>=?,
): Promise.t<result<B.execResult, B.execError>> => {
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
      let aborted = ref(false)
      let terminationError = ref(None)
      let processError = ref(None)
      let abortListener = ref(None)

      let decodeStdout = () => B.concatBuffers(stdoutChunks.contents)->B.bufferToStr
      let decodeStderr = () => B.concatBuffers(stderrChunks.contents)->B.bufferToStr

      let guardedResolve = value => {
        switch resolved.contents {
        | true => ()
        | false =>
          resolved := true
          switch (signal, abortListener.contents) {
          | (Some(signal), Some(listener)) =>
            signal->WebAPI.AbortSignal.removeEventListener(Abort, listener)
          | (Some(_), None) | (None, _) => ()
          }
          resolve(value)
        }
      }

      let abortNow = () => {
        aborted := true
        proc->B.kill(~signal="SIGTERM")->ignore
      }
      let onAbort = _event => abortNow()
      abortListener := Some(onAbort)
      signal->Option.forEach(signal => signal->WebAPI.AbortSignal.addEventListener(Abort, onAbort))
      switch signal {
      | Some({aborted: true}) => abortNow()
      | Some(_) | None => ()
      }

      proc
      ->B.processStdout
      ->B.onData(chunk => {
        switch resolved.contents {
        | true => ()
        | false =>
          switch terminationError.contents {
          | Some(_) => ()
          | None =>
            stdoutChunks.contents->Array.push(chunk)
            stdoutLen := stdoutLen.contents + B.bufferByteLength(chunk)
            switch stdoutLen.contents > maxBuffer {
            | true =>
              terminationError :=
                Some({
                  code: None,
                  B.stdout: decodeStdout(),
                  stderr: decodeStderr(),
                  message: "stdout maxBuffer exceeded",
                })
              proc->B.kill(~signal="SIGTERM")->ignore
            | false => ()
            }
          }
        }
      })

      proc
      ->B.processStderr
      ->B.onData(chunk => {
        switch resolved.contents {
        | true => ()
        | false =>
          switch terminationError.contents {
          | Some(_) => ()
          | None =>
            stderrChunks.contents->Array.push(chunk)
            stderrLen := stderrLen.contents + B.bufferByteLength(chunk)
            switch stderrLen.contents > maxBuffer {
            | true =>
              terminationError :=
                Some({
                  code: None,
                  B.stdout: decodeStdout(),
                  stderr: decodeStderr(),
                  message: "stderr maxBuffer exceeded",
                })
              proc->B.kill(~signal="SIGTERM")->ignore
            | false => ()
            }
          }
        }
      })

      proc->B.onProcess(
        #error(
          err => {
            switch (aborted.contents, terminationError.contents) {
            | (true, _) | (false, Some(_)) => ()
            | (false, None) =>
              processError :=
                Some({
                  code: None,
                  B.stdout: decodeStdout(),
                  stderr: decodeStderr(),
                  message: JsError.message(err),
                })
            }
          },
        ),
      )

      proc->B.onProcess(
        #close(
          nullableCode => {
            let code = nullableCode->Nullable.toOption
            switch (aborted.contents, terminationError.contents, processError.contents, code) {
            | (true, _, _, _) => guardedResolve(Error(abortedError()))
            | (false, Some(error), _, _) => guardedResolve(Error(error))
            | (false, None, Some(error), _) => guardedResolve(Error(error))
            | (false, None, None, Some(0)) =>
              guardedResolve(Ok({B.stdout: decodeStdout(), stderr: decodeStderr()}))
            | (false, None, None, _) =>
              let codeStr = code->Option.map(c => Int.toString(c))->Option.getOr("null")
              guardedResolve(
                Error({
                  code,
                  B.stdout: decodeStdout(),
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
      resolve(Error({code: None, B.stdout: "", stderr: "", message: msg}))
    }
  })
}

let exec = async (command: string): result<B.execResult, B.execError> => {
  await execPromise(command, {maxBuffer: defaultMaxBuffer})
}

let execWithOptions = async (
  command: string,
  options: B.execOptions,
  ~signal: option<WebAPI.EventTypes.abortSignal>=?,
): result<B.execResult, B.execError> => {
  await execPromise(command, options, ~signal?)
}

let spawnResult = async (
  command: string,
  args: array<string>,
  ~cwd: option<string>=?,
  ~signal: option<WebAPI.EventTypes.abortSignal>=?,
): result<B.execResult, B.execError> => {
  let options: B.execOptions = {
    ?cwd,
    maxBuffer: defaultMaxBuffer,
  }
  await spawnPromise(command, args, options, ~signal?)
}
