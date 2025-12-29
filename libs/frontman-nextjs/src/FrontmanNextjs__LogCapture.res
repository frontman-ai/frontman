module CircularBuffer = FrontmanNextjs__CircularBuffer

S.enableJson()

// Process error bindings
type processError = {
  message: option<string>,
  stack: option<string>,
  name: string,
}

// Rejection reason can be anything
type rejectionReason

@get external getReasonMessage: rejectionReason => option<string> = "message"
@get external getReasonStack: rejectionReason => option<string> = "stack"
@scope("String") external stringFromReason: rejectionReason => string = "toString"

// Process event listener binding
@val @scope("process")
external onProcessEvent: (string, 'a => unit) => unit = "on"

// Browser detection binding
@val external window: option<'a> = "window"

let isBrowser = (): bool => window->Option.isSome

// Global patch flag for double-patch prevention
type globalThis
@val external globalThis: globalThis = "globalThis"

@get
external getPatchedFlag: globalThis => option<bool> = "__FRONTMAN_CONSOLE_PATCHED__"

@set
external setPatchedFlagRaw: (globalThis, bool) => unit = "__FRONTMAN_CONSOLE_PATCHED__"

let getPatchedFlag = (): option<bool> => globalThis->getPatchedFlag
let setPatchedFlag = (value: bool): unit => globalThis->setPatchedFlagRaw(value)

@schema
type logLevel =
  | @as("console") Console
  | @as("build") Build
  | @as("error") Error

@schema
type consoleMethod =
  | @as("log") Log
  | @as("info") Info
  | @as("warn") Warn
  | @as("error") ConsoleError
  | @as("debug") Debug

@schema
type logEntry = {
  timestamp: string,
  level: logLevel,
  message: string,
  attributes: option<JSON.t>,
  resource: option<JSON.t>,
  consoleMethod: option<consoleMethod>,
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

let stripAnsi = (str: string): string => {
  // Matches: ESC followed by [@-Z\\-_] OR [ followed by optional params and final char
  str->String.replaceRegExp(/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g, "")
}

let addLog = (
  state: state,
  level: logLevel,
  message: string,
  ~attributes=?,
  ~consoleMethod=?,
): unit => {
  let cleanMessage = message->stripAnsi->String.trim

  if cleanMessage != "" {
    let entry = {
      timestamp: Date.now()->Date.fromTime->Date.toISOString,
      level,
      message: cleanMessage,
      attributes,
      resource: None,
      consoleMethod,
    }
    state.buffer := state.buffer.contents->CircularBuffer.push(entry)
  }
}

// Handlers for console methods - written in ReScript to use proper variants
let handleConsoleLog = (state: state, args: array<'a>): unit => {
  try {
    addLog(state, Console, argsToString(args), ~consoleMethod=Log)
  } catch {
  | _ => ()
  }
}

let handleConsoleWarn = (state: state, args: array<'a>): unit => {
  try {
    addLog(state, Console, argsToString(args), ~consoleMethod=Warn)
  } catch {
  | _ => ()
  }
}

let handleConsoleError = (state: state, args: array<'a>): unit => {
  try {
    addLog(state, Console, argsToString(args), ~consoleMethod=ConsoleError)
  } catch {
  | _ => ()
  }
}

let handleConsoleInfo = (state: state, args: array<'a>): unit => {
  try {
    addLog(state, Console, argsToString(args), ~consoleMethod=Info)
  } catch {
  | _ => ()
  }
}

let handleConsoleDebug = (state: state, args: array<'a>): unit => {
  try {
    addLog(state, Console, argsToString(args), ~consoleMethod=Debug)
  } catch {
  | _ => ()
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
        handleConsoleLog(state, args)
        originalLog.apply(console, args)
      }

      console.warn = function(...args) {
        handleConsoleWarn(state, args)
        originalWarn.apply(console, args)
      }

      console.error = function(...args) {
        handleConsoleError(state, args)
        originalError.apply(console, args)
      }

      console.info = function(...args) {
        handleConsoleInfo(state, args)
        originalInfo.apply(console, args)
      }

      console.debug = function(...args) {
        handleConsoleDebug(state, args)
        originalDebug.apply(console, args)
      }
    })()`)
  }
}

// Handler for stdout write - written in ReScript to use proper variants
let handleStdoutWrite = (state: state, message: string): unit => {
  try {
    if (
      message->String.includes("webpack") ||
      message->String.includes("turbopack") ||
      message->String.includes("Compiled") ||
      message->String.includes("Failed")
    ) {
      addLog(state, Build, message)
    }
  } catch {
  | _ => ()
  }
}

let interceptStdout = (state: state): unit => {
  if !state.initialized {
    %raw(`(function() {
      const originalWrite = process.stdout.write.bind(process.stdout)

      process.stdout.write = function(chunk, ...args) {
        const message = typeof chunk === 'string' ? chunk : chunk.toString()
        handleStdoutWrite(state, message)
        return originalWrite.apply(process.stdout, [chunk, ...args])
      }
    })()`)
  }
}

let interceptUncaughtErrors = (state: state): unit => {
  if !state.initialized {
    // Handle uncaught exceptions
    onProcessEvent("uncaughtException", (error: processError) => {
      try {
        let errorMessage = error.message->Option.getOr("Unknown error")
        let attributes =
          Dict.fromArray([
            ("stack", error.stack->Option.map(JSON.Encode.string)->Option.getOr(JSON.Encode.null)),
            ("name", error.name->JSON.Encode.string),
          ])->JSON.Encode.object
        addLog(state, Error, errorMessage, ~attributes)
      } catch {
      | _ => ()
      }
    })

    // Handle unhandled rejections
    onProcessEvent("unhandledRejection", (reason: rejectionReason) => {
      try {
        let reasonMessage =
          reason
          ->getReasonMessage
          ->Option.getOr(reason->stringFromReason)
        let attributes = Dict.fromArray([
          (
            "stack",
            reason
            ->getReasonStack
            ->Option.map(JSON.Encode.string)
            ->Option.getOr(JSON.Encode.null),
          ),
        ])->JSON.Encode.object
        addLog(state, Error, reasonMessage, ~attributes)
      } catch {
      | _ => ()
      }
    })
  }
}

let initialize = (): unit => {
  // Skip initialization in browser environments
  if isBrowser() {
    ()
  } else {
    // Check if already patched globally
    switch getPatchedFlag() {
    | Some(true) => () // Already patched, skip
    | _ => {
        let state = getInstance()
        interceptConsole(state)
        interceptStdout(state)
        interceptUncaughtErrors(state)
        setPatchedFlag(true)
        instance := Some({...state, initialized: true})
      }
    }
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
      allLogs->Array.filter(entry => entry.timestamp->Date.fromString->Date.getTime >= timestamp)
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
