// File operations module for CLI installer
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

module Detect = FrontmanNextjs__Cli__Detect
module Templates = FrontmanNextjs__Cli__Templates
module AutoEdit = FrontmanNextjs__Cli__AutoEdit
module Style = FrontmanNextjs__Cli__Style

// Result type for file operations
type fileResult =
  | Created(string)
  | Updated({fileName: string, oldHost: string, newHost: string})
  | Skipped(string)
  | ManualEditRequired({fileName: string, details: string})
  | AutoEdited(string)

// Pattern to match and replace host in existing file
let hostPattern = /host:\s*['\"]([^'\"]+)['\"]/

// Escape special replacement patterns ($1, $&, etc.) in a string used as
// the replacement argument to String.replaceRegExp
let escapeReplacement: string => string = %raw(`
  function(str) { return str.replace(/\$/g, '$$$$'); }
`)

// Update host in existing file content
let updateHostInContent = (content: string, newHost: string): string => {
  let safeHost = escapeReplacement(newHost)
  content->String.replaceRegExp(hostPattern, `host: '${safeHost}'`)
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

// Info about a file that needs auto-editing (collected before prompting)
type pendingAutoEdit = {
  filePath: string,
  fileName: string,
  fileType: AutoEdit.fileType,
  manualDetails: string,
}

// Handle the NeedsManualEdit case — when autoEdit is true, perform the edit;
// when false, return manual instructions
let handleNeedsManualEdit = async (
  ~filePath: string,
  ~fileName: string,
  ~host: string,
  ~fileType: AutoEdit.fileType,
  ~dryRun: bool,
  ~autoEdit: bool,
  ~manualDetails: string,
): result<fileResult, string> => {
  switch dryRun {
  | true => Ok(ManualEditRequired({fileName, details: manualDetails}))
  | false =>
    switch autoEdit {
    | false => Ok(ManualEditRequired({fileName, details: manualDetails}))
    | true =>
      switch await readFile(filePath) {
      | None => Ok(ManualEditRequired({fileName, details: manualDetails}))
      | Some(existingContent) =>
        switch await AutoEdit.autoEditFile(
          ~filePath,
          ~fileName,
          ~existingContent,
          ~fileType,
          ~host,
        ) {
        | AutoEdit.AutoEdited(name) => Ok(AutoEdited(name))
        | AutoEdit.AutoEditFailed(err) =>
          Console.log(Templates.SuccessMessages.autoEditFailed(fileName, err))
          Console.log(`     Falling back to manual instructions.`)
          Ok(ManualEditRequired({fileName, details: manualDetails}))
        }
      }
    }
  }
}

// Check if a file handler would need auto-editing (without prompting)
let getPendingAutoEdit = (
  ~existingFile: Detect.existingFile,
  ~filePath: string,
  ~fileName: string,
  ~fileType: AutoEdit.fileType,
  ~manualDetails: string,
): option<pendingAutoEdit> => {
  switch existingFile {
  | NeedsManualEdit => Some({filePath, fileName, fileType, manualDetails})
  | NotFound | HasFrontman(_) => None
  }
}

// Handle middleware file (Next.js 15 and earlier)
let handleMiddleware = async (
  ~projectDir: string,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool=false,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, "middleware.ts"])
  let fileName = "middleware.ts"

  switch existingFile {
  | NotFound =>
    switch dryRun {
    | true => Ok(Created(fileName))
    | false =>
      let content = Templates.middlewareTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    switch existingHost == host {
    | true => Ok(Skipped(fileName))
    | false =>
      switch dryRun {
      | true => Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
      | false =>
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
    await handleNeedsManualEdit(
      ~filePath,
      ~fileName,
      ~host,
      ~fileType=AutoEdit.Middleware,
      ~dryRun,
      ~autoEdit,
      ~manualDetails=Templates.ManualInstructions.middleware(fileName, host),
    )
  }
}

// Handle proxy file (Next.js 16+)
let handleProxy = async (
  ~projectDir: string,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool=false,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, "proxy.ts"])
  let fileName = "proxy.ts"

  switch existingFile {
  | NotFound =>
    switch dryRun {
    | true => Ok(Created(fileName))
    | false =>
      let content = Templates.proxyTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    switch existingHost == host {
    | true => Ok(Skipped(fileName))
    | false =>
      switch dryRun {
      | true => Ok(Updated({fileName, oldHost: existingHost, newHost: host}))
      | false =>
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
    await handleNeedsManualEdit(
      ~filePath,
      ~fileName,
      ~host,
      ~fileType=AutoEdit.Proxy,
      ~dryRun,
      ~autoEdit,
      ~manualDetails=Templates.ManualInstructions.proxy(fileName, host),
    )
  }
}

// Handle instrumentation file
let handleInstrumentation = async (
  ~projectDir: string,
  ~host: string,
  ~hasSrcDir: bool,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool=false,
): result<fileResult, string> => {
  let filePath = switch hasSrcDir {
  | true => Path.join([projectDir, "src", "instrumentation.ts"])
  | false => Path.join([projectDir, "instrumentation.ts"])
  }
  let fileName = switch hasSrcDir {
  | true => "src/instrumentation.ts"
  | false => "instrumentation.ts"
  }

  switch existingFile {
  | NotFound =>
    switch dryRun {
    | true => Ok(Created(fileName))
    | false =>
      // Ensure src/ directory exists if needed
      switch hasSrcDir {
      | true =>
        let srcDir = Path.join([projectDir, "src"])
        let _ = await Fs.Promises.mkdir(srcDir, {recursive: true})
      | false => ()
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
    await handleNeedsManualEdit(
      ~filePath,
      ~fileName,
      ~host,
      ~fileType=AutoEdit.Instrumentation,
      ~dryRun,
      ~autoEdit,
      ~manualDetails=Templates.ManualInstructions.instrumentation(fileName),
    )
  }
}

// Format file result for display (short one-liner)
let formatResult = (result: fileResult): string => {
  switch result {
  | Created(fileName) => Templates.SuccessMessages.fileCreated(fileName)
  | Updated({fileName, oldHost, newHost}) =>
    Templates.SuccessMessages.hostUpdated(fileName, oldHost, newHost)
  | Skipped(fileName) => Templates.SuccessMessages.fileSkipped(fileName)
  | ManualEditRequired({fileName, _}) => Templates.SuccessMessages.manualEditRequired(fileName)
  | AutoEdited(fileName) => Templates.SuccessMessages.fileAutoEdited(fileName)
  }
}

// Check if result is an error that requires manual intervention
let isManualEditRequired = (result: fileResult): bool => {
  switch result {
  | ManualEditRequired(_) => true
  | Created(_) | Updated(_) | Skipped(_) | AutoEdited(_) => false
  }
}
