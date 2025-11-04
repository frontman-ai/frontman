module Types = Logger__Types

module type Config = {
  let output: Logger__Types.logEntry => unit
  let minLevel: Logger__Types.level
  let enabled: bool
}

module Make = (C: Config) => {
  let makeEntry = (
    level: Logger__Types.level,
    message: string,
    metadata: option<JSON.t>,
  ): Logger__Types.logEntry => {
    level,
    message,
    metadata,
  }

  let emit = (entry: Logger__Types.logEntry): unit => {
    if C.enabled && Logger__Types.shouldLog(entry.level, C.minLevel) {
      C.output(entry)
    }
  }
  let debug = (message: string): unit => {
    emit(makeEntry(Logger__Types.Debug, message, None))
  }

  let debugWithMeta = (message: string, metadata: JSON.t): unit => {
    emit(makeEntry(Logger__Types.Debug, message, Some(metadata)))
  }

  let info = (message: string): unit => {
    emit(makeEntry(Logger__Types.Info, message, None))
  }

  let infoWithMeta = (message: string, metadata: JSON.t): unit => {
    emit(makeEntry(Logger__Types.Info, message, Some(metadata)))
  }

  let warn = (message: string): unit => {
    emit(makeEntry(Logger__Types.Warn, message, None))
  }

  let warnWithMeta = (message: string, metadata: JSON.t): unit => {
    emit(makeEntry(Logger__Types.Warn, message, Some(metadata)))
  }

  let error = (message: string): unit => {
    emit(makeEntry(Logger__Types.Error, message, None))
  }

  let errorWithMeta = (message: string, metadata: JSON.t): unit => {
    emit(makeEntry(Logger__Types.Error, message, Some(metadata)))
  }
}
