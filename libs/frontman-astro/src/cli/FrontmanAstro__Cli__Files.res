// File operations module for CLI installer
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

module Detect = FrontmanAstro__Cli__Detect
module Templates = FrontmanAstro__Cli__Templates
module AutoEdit = FrontmanAstro__Cli__AutoEdit
module Style = FrontmanAstro__Cli__Style

// Result type for file operations
type fileResult =
  | Created(string)
  | Updated({fileName: string, oldHost: string, newHost: string})
  | Skipped(string)
  | ManualEditRequired({fileName: string, details: string})
  | AutoEdited(string)

// Pattern to match and replace host in existing file
let hostPattern = %re("/host:\s*['\"]([^'\"]+)['\"]/")

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

// Handle astro.config.mjs file
let handleConfig = async (
  ~projectDir: string,
  ~host: string,
  ~configFileName: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool=false,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, configFileName])
  let fileName = configFileName

  switch existingFile {
  | NotFound =>
    switch dryRun {
    | true => Ok(Created(fileName))
    | false =>
      let content = Templates.configTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    // Config files don't contain host themselves (host is in middleware),
    // so an empty existingHost means Frontman is already configured — skip.
    switch existingHost == host || existingHost == "" {
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
      ~fileType=AutoEdit.Config,
      ~dryRun,
      ~autoEdit,
      ~manualDetails=Templates.ManualInstructions.config(fileName, host),
    )
  }
}

// Handle src/middleware.ts (or .js) file
let handleMiddleware = async (
  ~projectDir: string,
  ~host: string,
  ~middlewareFileName: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool=false,
): result<fileResult, string> => {
  let filePath = Path.join([projectDir, middlewareFileName])
  let fileName = middlewareFileName

  switch existingFile {
  | NotFound =>
    switch dryRun {
    | true => Ok(Created(fileName))
    | false =>
      // Ensure src/ directory exists
      let srcDir = Path.join([projectDir, "src"])
      let _ = await Fs.Promises.mkdir(srcDir, {recursive: true})
      let content = Templates.middlewareTemplate(host)
      switch await writeFile(filePath, content) {
      | Ok() => Ok(Created(fileName))
      | Error(e) => Error(e)
      }
    }

  | HasFrontman({host: existingHost}) =>
    // When analyzeFile can't extract a host (e.g. host: process.env.FRONTMAN_HOST),
    // it returns HasFrontman({host: ""}). Treat empty host as already configured
    // to avoid rewriting the file unchanged with a misleading "Updated" message.
    switch existingHost == host || existingHost == "" {
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
