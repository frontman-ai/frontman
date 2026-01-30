// File operations module for CLI installer
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

module Detect = FrontmanNextjs__Cli__Detect
module Templates = FrontmanNextjs__Cli__Templates

// Result type for file operations
type fileResult =
  | Created(string)
  | Updated({fileName: string, oldHost: string, newHost: string})
  | Skipped(string)
  | ManualEditRequired(string)

// Pattern to match and replace host in existing file
let hostPattern = %re("/host:\s*['\"]([^'\"]+)['\"]/")

// Update host in existing file content
let updateHostInContent = (content: string, newHost: string): string => {
  content->String.replaceRegExp(hostPattern, `host: '${newHost}'`)
}

// Read file content
let readFile = async (path: string): option<string> => {
  try {
    let content = await Fs.Promises.readFile(path)
    Some(content)
  } catch {
  | _ => None
  }
}

// Write file content
let writeFile = async (path: string, content: string): result<unit, string> => {
  try {
    await Fs.Promises.writeFile(path, content)
    Ok()
} catch {
| _ => Error(`Failed to write ${path}`)
}
}

// Handle middleware file (Next.js 15 and earlier)
let handleMiddleware = async (
  ~projectDir: string,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, "middleware.ts"])
  let fileName = "middleware.ts"

  switch existingFile {
  | NotFound =>
    if dryRun {
      Ok(Created(fileName))
    } else {
      let content = Templates.middlewareTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    if existingHost == host {
      Ok(Skipped(fileName))
    } else {
      if dryRun {
        Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
      } else {
        switch await readFile(filePath) {
        | None => Error(`Failed to read ${fileName}`)
        | Some(content) =>
          let newContent = updateHostInContent(content, host)
          switch await writeFile(filePath, newContent) {
          | Ok() => Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
          | Error(e) => Error(e)
          }
        }
      }
    }

  | NeedsManualEdit =>
    Ok(ManualEditRequired(Templates.ErrorMessages.middlewareManualSetup(fileName, host)))
  }
}

// Handle proxy file (Next.js 16+)
let handleProxy = async (
  ~projectDir: string,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, "proxy.ts"])
  let fileName = "proxy.ts"

  switch existingFile {
  | NotFound =>
    if dryRun {
      Ok(Created(fileName))
    } else {
      let content = Templates.proxyTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    if existingHost == host {
      Ok(Skipped(fileName))
    } else {
      if dryRun {
        Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
      } else {
        switch await readFile(filePath) {
        | None => Error(`Failed to read ${fileName}`)
        | Some(content) =>
          let newContent = updateHostInContent(content, host)
          switch await writeFile(filePath, newContent) {
          | Ok() => Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
          | Error(e) => Error(e)
          }
        }
      }
    }

  | NeedsManualEdit =>
    Ok(ManualEditRequired(Templates.ErrorMessages.proxyManualSetup(fileName, host)))
  }
}

// Handle instrumentation file
let handleInstrumentation = async (
  ~projectDir: string,
  ~hasSrcDir: bool,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
): result<fileResult, string> => {
  let filePath = if hasSrcDir {
    Path.join([projectDir, "src", "instrumentation.ts"])
  } else {
    Path.join([projectDir, "instrumentation.ts"])
  }
  let fileName = if hasSrcDir {
    "src/instrumentation.ts"
  } else {
    "instrumentation.ts"
  }

  switch existingFile {
  | NotFound =>
    if dryRun {
      Ok(Created(fileName))
    } else {
      // Ensure src/ directory exists if needed
      if hasSrcDir {
        let srcDir = Path.join([projectDir, "src"])
        let _ = await Fs.Promises.mkdir(srcDir, {recursive: true})
      }
      let content = Templates.instrumentationTemplate()
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman(_) =>
    // Instrumentation doesn't have a host to update, just skip
    Ok(Skipped(fileName))

  | NeedsManualEdit =>
    Ok(ManualEditRequired(Templates.ErrorMessages.instrumentationManualSetup(fileName)))
  }
}

// Format file result for display
let formatResult = (result: fileResult): string => {
  switch result {
  | Created(fileName) => Templates.SuccessMessages.fileCreated(fileName)
  | Updated({fileName, oldHost, newHost}) =>
    Templates.SuccessMessages.hostUpdated(fileName, oldHost, newHost)
  | Skipped(fileName) => Templates.SuccessMessages.fileSkipped(fileName)
  | ManualEditRequired(message) => message
  }
}

// Check if result is an error that requires manual intervention
let isManualEditRequired = (result: fileResult): bool => {
  switch result {
  | ManualEditRequired(_) => true
  | _ => false
  }
}
