# @ask-the-llm/logger

Pure ReScript logger with EventBus integration, automatic file/line tracking, and compile-time disable.

## Features

- **4 log levels**: Debug, Info, Warn, Error
- **Automatic file/line tracking**: Uses `__FILE__` and `__LINE__` special variables
- **Consumer-defined output**: Pluggable output handlers via functor
- **EventBus integration**: Optional log event emission to EventBus
- **Compile-time disable**: Edit one file to remove ALL logs from bundle
- **Metadata support**: Pretty-print complex objects
- **Zero dependencies**: Pure ReScript (except sury for @schema)

## Usage

### Agent Library (Node.js)

```rescript
// Already configured in Agent__Logger.res
Agent__Logger.Log.debug(~file=__FILE__, ~line=__LINE__, "Debug message")
Agent__Logger.Log.info(~file=__FILE__, ~line=__LINE__, "Info message")
Agent__Logger.Log.warn(~file=__FILE__, ~line=__LINE__, "Warning message")
Agent__Logger.Log.error(~file=__FILE__, ~line=__LINE__, "Error message")

// With metadata
Agent__Logger.Log.infoWithMeta(~file=__FILE__, ~line=__LINE__, "Message", someJSON)
```

### Creating a Logger

```rescript
// MyLibrary__Logger.res
module Log = AskTheLlmLogger.Logger.Make({
  let output = (entry: AskTheLlmLogger.Logger.Types.logEntry): unit => {
    // Console output
    Console.log3(entry.file, entry.line, entry.message)

    // Optional: emit to EventBus
    myEventBus->EventBus.emit(LogEvent(entry))
  }

  let minLevel = AskTheLlmLogger.Logger.Types.Debug
})
```

### Disabling All Logs

Edit `libs/logger/src/Logger__Config.res`:

```rescript
let enabled = false  // Compile-time elimination!
```

Rebuild and all log code is removed from the bundle via dead code elimination.

## Architecture

- **Logger.res**: Functor with consumer-defined output
- **Logger__Types.res**: Log levels and entry types
- **Logger__Config.res**: Global enable/disable flag

## Output Format

Console output shows: `[file:line] message`

Example:
```
Agent__Reactor.res 21 Reactor: Created event - no action needed
Agent__Effect.res 38 Executing tool: read_file
```

## EventBus Integration

Logs can automatically emit `LogEvent` to the EventBus for subscribers (like client UI) to handle.
