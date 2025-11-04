// Log levels
@schema
type level = Debug | Info | Warn | Error

// Log entry structure
@schema
type logEntry = {
  level: level,
  message: string,
  metadata: option<JSON.t>,
}

// Helper to convert level to string
let levelToString = (level: level): string =>
  switch level {
  | Debug => "DEBUG"
  | Info => "INFO"
  | Warn => "WARN"
  | Error => "ERROR"
  }

// Helper to compare log levels
let levelToInt = (level: level): int =>
  switch level {
  | Debug => 0
  | Info => 1
  | Warn => 2
  | Error => 3
  }

let shouldLog = (level: level, minLevel: level): bool => levelToInt(level) >= levelToInt(minLevel)
