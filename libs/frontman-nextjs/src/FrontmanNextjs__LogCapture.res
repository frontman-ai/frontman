module CircularBuffer = FrontmanNextjs__CircularBuffer

S.enableJson()

@schema
type logLevel =
  | @as("console") Console
  | @as("build") Build
  | @as("error") Error

@schema
type logEntry = {
  timestamp: string,
  level: logLevel,
  message: string,
  attributes: option<JSON.t>,
  resource: option<JSON.t>,
}

type state = {
  buffer: ref<CircularBuffer.t<logEntry>>,
  initialized: bool,
}

let instance: ref<option<state>> = ref(None)

let getInstance = (): state => {
  switch instance.contents {
  | Some(state) => state
  | None =>
    let state = {
      buffer: ref(CircularBuffer.make(~capacity=1024)),
      initialized: false,
    }
    instance := Some(state)
    state
  }
}

let stripAnsi = (str: string): string => {
  str->String.replaceRegExp(/\x1b\[[0-9;]*m/g, "")
}

let argsToString = (args: array<'a>): string => {
  args
  ->Array.map(arg => {
    switch %raw(`typeof arg`) {
    | "string" => arg->Obj.magic
    | "object" =>
      if %raw(`arg instanceof Error`) {
        let error = arg->Obj.magic
        error["stack"]->Obj.magic->Option.getOr(error["message"]->Obj.magic)
      } else {
        %raw(`JSON.stringify(arg)`)
      }
    | _ => %raw(`String(arg)`)
    }
  })
  ->Array.join(" ")
}

let addLog = (state: state, level: logLevel, message: string, ~attributes=?): unit => {
  let cleanMessage = message->stripAnsi->String.trim

  if cleanMessage != "" {
    let entry = {
      timestamp: Date.now()->Date.fromTime->Date.toISOString,
      level,
      message: cleanMessage,
      attributes,
      resource: None,
    }
    state.buffer := state.buffer.contents->CircularBuffer.push(entry)
  }
}

let interceptConsole = (state: state): unit => {
  if !state.initialized {
    %raw(`(function() {
      const originalLog = console.log.bind(console)
      const originalWarn = console.warn.bind(console)
      const originalError = console.error.bind(console)
      const originalInfo = console.info.bind(console)
      const originalDebug = console.debug.bind(console)

      console.log = function(...args) {
        try {
          addLog(state, {TAG: 0}, argsToString(args))
        } catch {}
        originalLog.apply(console, args)
      }

      console.warn = function(...args) {
        try {
          addLog(state, {TAG: 0}, argsToString(args))
        } catch {}
        originalWarn.apply(console, args)
      }

      console.error = function(...args) {
        try {
          addLog(state, {TAG: 0}, argsToString(args))
        } catch {}
        originalError.apply(console, args)
      }

      console.info = function(...args) {
        try {
          addLog(state, {TAG: 0}, argsToString(args))
        } catch {}
        originalInfo.apply(console, args)
      }

      console.debug = function(...args) {
        try {
          addLog(state, {TAG: 0}, argsToString(args))
        } catch {}
        originalDebug.apply(console, args)
      }
    })()`)
  }
}

let interceptStdout = (state: state): unit => {
  if !state.initialized {
    %raw(`(function() {
      const originalWrite = process.stdout.write.bind(process.stdout)

      process.stdout.write = function(chunk, ...args) {
        try {
          const message = typeof chunk === 'string' ? chunk : chunk.toString()
          if (message.includes('webpack') || message.includes('turbopack') ||
              message.includes('Compiled') || message.includes('Failed')) {
            addLog(state, {TAG: 1}, message)
          }
        } catch {}
        return originalWrite.apply(process.stdout, [chunk, ...args])
      }
    })()`)
  }
}

let interceptUncaughtErrors = (state: state): unit => {
  if !state.initialized {
    %raw(`
      process.on('uncaughtException', (error) => {
        try {
          const attributes = {
            stack: error.stack,
            name: error.name
          }
          addLog(state, {TAG: 3}, error.message || String(error), attributes)
        } catch {}
      })
    `)

    %raw(`
      process.on('unhandledRejection', (reason) => {
        try {
          const attributes = {
            stack: reason?.stack
          }
          addLog(state, {TAG: 3}, reason?.message || String(reason), attributes)
        } catch {}
      })
    `)
  }
}

let initialize = (): unit => {
  let state = getInstance()
  if !state.initialized {
    interceptConsole(state)
    interceptStdout(state)
    interceptUncaughtErrors(state)
    instance := Some({...state, initialized: true})
  }
}

let getLogs = (
  ~pattern: option<string>=?,
  ~level: option<logLevel>=?,
  ~since: option<float>=?,
  ~tail: option<int>=?,
): array<logEntry> => {
  try {
    let state = getInstance()
    let allLogs = state.buffer.contents->CircularBuffer.toArray

    let logs = switch since {
    | Some(timestamp) =>
      allLogs->Array.filter(entry =>
        entry.timestamp->Date.fromString->Date.getTime >= timestamp
      )
    | None => allLogs
    }

    let logs = switch level {
    | Some(filterLevel) => logs->Array.filter(entry => entry.level == filterLevel)
    | None => logs
    }

    let logs = switch pattern {
    | Some(p) =>
      let regex = Js.Re.fromStringWithFlags(p, ~flags="i")
      logs->Array.filter(entry => Js.Re.test_(regex, entry.message))
    | None => logs
    }

    switch tail {
    | Some(n) =>
      let len = logs->Array.length
      logs->Array.slice(~start=max(0, len - n), ~end=len)
    | None => logs
    }
  } catch {
  | _ => []
  }
}
