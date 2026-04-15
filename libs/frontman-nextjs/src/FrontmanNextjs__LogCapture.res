@moduledoc(`
Captures console logs, build output, and uncaught errors in Node.js environments.

Logs are stored in a circular buffer and can be queried with filters. Call
\`initialize()\` once at app startup. Browser environments are automatically skipped.

Configure buffer size and stdout patterns via optional config parameter.
`)
module CircularBuffer = FrontmanNextjs__CircularBuffer

S.enableJson()

let isBrowser = (): bool => %raw(`typeof window !== 'undefined'`)

// Custom globalThis properties for Frontman
let getPatchedFlag = (): option<bool> => %raw(`globalThis.__FRONTMAN_CONSOLE_PATCHED__`)
let setPatchedFlag = (_value: bool): unit =>
  %raw(`globalThis.__FRONTMAN_CONSOLE_PATCHED__ = _value`)

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

type config = {
  bufferCapacity: int,
  stdoutPatterns: array<string>,
}

let defaultConfig: config = {
  bufferCapacity: 1024,
  stdoutPatterns: ["webpack", "turbopack", "Compiled", "Failed"],
}

type state = {
  buffer: ref<CircularBuffer.t<logEntry>>,
  config: config,
}

let getGlobalInstanceOpt = (): option<state> => %raw(`globalThis.__FRONTMAN_INSTANCE__`)
let setGlobalInstance = (_state: state): unit => %raw(`globalThis.__FRONTMAN_INSTANCE__ = _state`)

let getOrCreateInstance = (~config: config): state => {
  switch getGlobalInstanceOpt() {
  | Some(state) => state
  | None =>
    let state = {
      buffer: ref(CircularBuffer.make(~capacity=config.bufferCapacity)),
      config,
    }
    setGlobalInstance(state)
    state
  }
}

let getInstance = (): state => {
  switch getGlobalInstanceOpt() {
  | Some(state) => state
  | None => getOrCreateInstance(~config=defaultConfig)
  }
}

let argsToString = (args: array<'a>): string => {
  args
  ->Array.map(arg => {
    switch arg->Type.typeof {
    | #string => arg->Obj.magic
    | #object =>
      if %raw(`arg instanceof Error`) {
        let error = arg->Obj.magic
        error["stack"]->Obj.magic->Option.getOr(error["message"]->Obj.magic)
      } else {
        arg->JSON.stringifyAny->Option.getOr("null")
      }
    | _ => arg->String.make
    }
  })
  ->Array.join(" ")
}

let stripAnsi = (str: string): string => {
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

let detectLevel = (state: state, message: string): logLevel => {
  let matchesBuildPattern =
    state.config.stdoutPatterns->Array.some(pattern => message->String.includes(pattern))
  switch matchesBuildPattern {
  | true => Build
  | false => Console
  }
}

let handleConsoleLog = (state: state, args: array<'a>): unit => {
  let message = argsToString(args)
  addLog(state, detectLevel(state, message), message, ~consoleMethod=Log)
}

let handleConsoleWarn = (state: state, args: array<'a>): unit => {
  let message = argsToString(args)
  addLog(state, detectLevel(state, message), message, ~consoleMethod=Warn)
}

let handleConsoleError = (state: state, args: array<'a>): unit => {
  let message = argsToString(args)
  addLog(state, detectLevel(state, message), message, ~consoleMethod=ConsoleError)
}

let handleConsoleInfo = (state: state, args: array<'a>): unit => {
  let message = argsToString(args)
  addLog(state, detectLevel(state, message), message, ~consoleMethod=Info)
}

let handleConsoleDebug = (state: state, args: array<'a>): unit => {
  let message = argsToString(args)
  addLog(state, detectLevel(state, message), message, ~consoleMethod=Debug)
}

// Variadic interceptConsole implemented in raw JavaScript to fix variadic arguments bug
let interceptConsole: state => unit = %raw(`(function(state) {
  const originalLog = console.log.bind(console);
  const originalWarn = console.warn.bind(console);
  const originalError = console.error.bind(console);
  const originalInfo = console.info.bind(console);
  const originalDebug = console.debug.bind(console);

  console.log = (...args) => {
    originalLog(...args);
    handleConsoleLog(state, args);
  };
  console.warn = (...args) => {
    originalWarn(...args);
    handleConsoleWarn(state, args);
  };
  console.error = (...args) => {
    originalError(...args);
    handleConsoleError(state, args);
  };
  console.info = (...args) => {
    originalInfo(...args);
    handleConsoleInfo(state, args);
  };
  console.debug = (...args) => {
    originalDebug(...args);
    handleConsoleDebug(state, args);
  };
})`)

// Temporary inline bindings until workspace linking is fixed
type processError = {
  message: option<string>,
  stack: option<string>,
  name: string,
}

type rejectionReason
@get external getReasonMessage: rejectionReason => option<string> = "message"
@get external getReasonStack: rejectionReason => option<string> = "stack"
@scope("String") external stringFromReason: rejectionReason => string = "toString"

@val @scope("process")
external onProcessEvent: (string, 'a => unit) => unit = "on"

let interceptUncaughtErrors = (state: state): unit => {
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

let initialize = (~config: config=defaultConfig, ()): unit => {
  if isBrowser() {
    ()
  } else {
    switch getPatchedFlag() {
    | Some(true) => ()
    | _ => {
        setPatchedFlag(true)
        let state = getOrCreateInstance(~config)
        interceptConsole(state)
        interceptUncaughtErrors(state)
      }
    }
  }
}

type regexCache = {
  mutable pattern: option<string>,
  mutable regex: option<Js.Re.t>,
}

let regexCache: regexCache = {
  pattern: None,
  regex: None,
}

let getCompiledRegex = (pattern: string): Js.Re.t => {
  switch regexCache.pattern {
  | Some(cached) if cached === pattern =>
    switch regexCache.regex {
    | Some(r) => r
    | None =>
      let regex = Js.Re.fromStringWithFlags(pattern, ~flags="i")
      regexCache.regex = Some(regex)
      regex
    }
  | _ =>
    let regex = Js.Re.fromStringWithFlags(pattern, ~flags="i")
    regexCache.pattern = Some(pattern)
    regexCache.regex = Some(regex)
    regex
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
      let regex = getCompiledRegex(p)
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

// This ensures console is patched before any other code runs
// Use %%raw to ensure this executes at module load time
%%raw(`
// Initialize LogCapture when module is imported
if (typeof window === 'undefined') {
  initialize();
}
`)
