// Bindings for Node.js child_process module

type childProcess

type spawnOptions = {
  stdio?: array<string>,
  cwd?: string,
  env?: Dict.t<string>,
}

// Spawn a child process
@module("node:child_process")
external spawn: (string, array<string>, spawnOptions) => childProcess = "spawn"

// ChildProcess properties - now reference Bindings__NodeStreams
@get external stdin: childProcess => option<NodeStreams.writable> = "stdin"
@get external stdout: childProcess => option<NodeStreams.readable> = "stdout"
@get external stderr: childProcess => option<NodeStreams.readable> = "stderr"

// ChildProcess methods
@send external kill: (childProcess, ~signal: string=?) => bool = "kill"

// Event listeners for child process
@send
external on: (
  childProcess,
  @string
  [
    | #exit((option<int>, option<string>) => unit)
    | #error(JsError.t => unit)
    | #close((option<int>, option<string>) => unit)
  ],
) => unit = "on"

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
}

// Direct Promise-based exec implementation in raw JavaScript
let execPromise: (string, execOptions) => Promise.t<execResult> = %raw(`
  async function(command, options) {
    const { exec } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execP = promisify(exec);
    return await execP(command, options);
  }
`)

// Helper to convert Buffer to string if needed
let bufferToString: 'a => string = %raw(`
  function(value) {
    if (value == null) return "";
    if (typeof value === "string") return value;
    if (Buffer.isBuffer(value)) return value.toString("utf8");
    return String(value);
  }
`)

// Helper to execute command and return result or error
let exec = async (command: string): result<execResult, execError> => {
  try {
    // Increase maxBuffer to 50MB to handle large grep outputs
    let result = await execPromise(command, {maxBuffer: 50 * 1024 * 1024})
    Ok({
      stdout: bufferToString(result.stdout),
      stderr: bufferToString(result.stderr),
    })
  } catch {
  | exn => {
      // Parse the error to extract stdout/stderr if available
      // ReScript wraps JS exceptions, so we need to extract the actual error from _1
      let error = exn->Obj.magic
      let actualError = error["_1"]->Nullable.toOption->Option.getOr(error)
      Error({
        code: actualError["code"]->Nullable.toOption,
        stdout: actualError["stdout"]
        ->Nullable.toOption
        ->Option.map(bufferToString)
        ->Option.getOr(""),
        stderr: actualError["stderr"]
        ->Nullable.toOption
        ->Option.map(bufferToString)
        ->Option.getOr(""),
      })
    }
  }
}

let execWithOptions = async (command: string, options: execOptions): result<
  execResult,
  execError,
> => {
  try {
    // Merge options with a default maxBuffer of 50MB if not specified
    let optionsWithDefaults = {
      ...options,
      maxBuffer: options.maxBuffer->Option.getOr(50 * 1024 * 1024),
    }
    let result = await execPromise(command, optionsWithDefaults)
    Ok({
      stdout: bufferToString(result.stdout),
      stderr: bufferToString(result.stderr),
    })
  } catch {
  | exn => {
      // ReScript wraps JS exceptions, so we need to extract the actual error from _1
      let error = exn->Obj.magic
      let actualError = error["_1"]->Nullable.toOption->Option.getOr(error)
      Error({
        code: actualError["code"]->Nullable.toOption,
        stdout: actualError["stdout"]
        ->Nullable.toOption
        ->Option.map(bufferToString)
        ->Option.getOr(""),
        stderr: actualError["stderr"]
        ->Nullable.toOption
        ->Option.map(bufferToString)
        ->Option.getOr(""),
      })
    }
  }
}
