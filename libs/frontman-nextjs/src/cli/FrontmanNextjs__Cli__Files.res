module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

module Detect = FrontmanNextjs__Cli__Detect
module Templates = FrontmanNextjs__Cli__Templates
module AutoEdit = FrontmanNextjs__Cli__AutoEdit
module Style = FrontmanNextjs__Cli__Style

type fileResult =
  | Created(string)
  | Updated({fileName: string, oldHost: string, newHost: string})
  | Skipped(string)
  | ManualEditRequired({fileName: string, details: string})
  | AutoEdited(string)

let hostPattern = /host:\s*['\"]([^'\"]+)['\"]/

let escapeReplacement: string => string = %raw(`
  function(str) { return str.replace(/\$/g, '$$$$'); }
`)

let updateHostInContent = (content: string, newHost: string): string => {
  let safeHost = escapeReplacement(newHost)
  content->String.replaceRegExp(hostPattern, `host: '${safeHost}'`)
}

let readFile = async (path: string): option<string> => {
  try {
    let content = await Fs.Promises.readFile(path)
    Some(content)
  } catch {
  | _ => None
  }
}

let writeFile = async (path: string, content: string): result<unit, string> => {
  try {
    await Fs.Promises.writeFile(path, content)
    Ok()
  } catch {
  | _ => Error(`Failed to write ${path}`)
  }
}

type pendingAutoEdit = {
  fileName: string,
}

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

let getPendingAutoEdit = (~existingFile: Detect.existingFile, ~fileName: string): option<
  pendingAutoEdit,
> => {
  switch existingFile {
  | NeedsManualEdit => Some({fileName: fileName})
  | NotFound | HasFrontman(_) => None
  }
}

let handleMiddleware = async (
  ~projectDir: string,
  ~hasSrcDir: bool,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool,
): result<fileResult, string> => {
  let filePath = switch hasSrcDir {
  | true => Path.join([projectDir, "src", "middleware.ts"])
  | false => Path.join([projectDir, "middleware.ts"])
  }
  let fileName = switch hasSrcDir {
  | true => "src/middleware.ts"
  | false => "middleware.ts"
  }

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

let handleProxy = async (
  ~projectDir: string,
  ~hasSrcDir: bool,
  ~host: string,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool,
): result<fileResult, string> => {
  let filePath = switch hasSrcDir {
  | true => Path.join([projectDir, "src", "proxy.ts"])
  | false => Path.join([projectDir, "proxy.ts"])
  }
  let fileName = switch hasSrcDir {
  | true => "src/proxy.ts"
  | false => "proxy.ts"
  }

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

let handleInstrumentation = async (
  ~projectDir: string,
  ~host: string,
  ~hasSrcDir: bool,
  ~existingFile: Detect.existingFile,
  ~dryRun: bool,
  ~autoEdit: bool,
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

  | HasFrontman(_) => Ok(Skipped(fileName))

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

let validateIntegration = async (
  ~projectDir: string,
  ~hasSrcDir: bool,
  ~isNext16Plus: bool,
  ~host: string,
): result<unit, string> => {
  let entrypoint = switch (hasSrcDir, isNext16Plus) {
  | (true, true) => Path.join([projectDir, "src", "proxy.ts"])
  | (false, true) => Path.join([projectDir, "proxy.ts"])
  | (true, false) => Path.join([projectDir, "src", "middleware.ts"])
  | (false, false) => Path.join([projectDir, "middleware.ts"])
  }
  let instrumentation = switch hasSrcDir {
  | true => Path.join([projectDir, "src", "instrumentation.ts"])
  | false => Path.join([projectDir, "instrumentation.ts"])
  }

  switch await Detect.analyzeFile(entrypoint) {
  | Detect.NotFound => Error("Health check failed: entrypoint was not written")
  | Detect.NeedsManualEdit => Error("Health check failed: entrypoint is not a Frontman integration")
  | Detect.HasFrontman({host: entrypointHost}) =>
    switch entrypointHost == host {
    | true =>
      switch await Detect.analyzeFile(instrumentation) {
      | Detect.HasFrontman(_) => Ok()
      | Detect.NotFound => Error("Health check failed: instrumentation was not written")
      | Detect.NeedsManualEdit => Error("Health check failed: instrumentation is not a Frontman integration")
      }
    | false => Error(`Health check failed: entrypoint host is ${entrypointHost}`)
    }
  }
}

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
