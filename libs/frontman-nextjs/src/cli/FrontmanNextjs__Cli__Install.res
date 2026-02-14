// Install command implementation
module Bindings = FrontmanBindings
module ChildProcess = Bindings.ChildProcess
module Path = Bindings.Path
module Process = Bindings.Process

module AutoEdit = FrontmanNextjs__Cli__AutoEdit
module Detect = FrontmanNextjs__Cli__Detect
module Files = FrontmanNextjs__Cli__Files
module Templates = FrontmanNextjs__Cli__Templates
module Style = FrontmanNextjs__Cli__Style

type installOptions = {
  server: string,
  prefix: option<string>,
  dryRun: bool,
  skipDeps: bool,
}

type installResult =
  | Success
  | PartialSuccess({manualStepsRequired: array<string>})
  | Failure(string)

// Install dependencies using detected package manager
let installDependencies = async (
  ~projectDir: string,
  ~packageManager: Detect.packageManager,
  ~dryRun: bool,
): result<unit, string> => {
  let pm = Detect.getPackageManagerCommand(packageManager)
  let args = Detect.getInstallArgs(packageManager)
  let packages = ["@frontman-ai/nextjs", "@opentelemetry/sdk-node"]
  // Deno requires npm: prefix for npm packages (otherwise it looks them up on JSR)
  let packages = switch packageManager {
  | Deno => packages->Array.map(p => "npm:" ++ p)
  | _ => packages
  }
  let cmd = `${pm} ${args->Array.join(" ")} ${packages->Array.join(" ")}`

  switch dryRun {
  | true =>
    Console.log(`  ${Style.dim(`Would run: ${cmd}`)}`)
    Ok()
  | false =>
    Console.log(`  ${Style.purple("Installing dependencies with " ++ pm ++ "...")}`)

    switch await ChildProcess.execWithOptions(cmd, {cwd: projectDir}) {
    | Ok(_) =>
      Console.log(`  ${Style.check} Dependencies installed`)
      Ok()
    | Error(err) =>
      let stderr = switch err.stderr == "" {
      | true => "Unknown error"
      | false => err.stderr
      }
      Error(`Failed to install dependencies: ${stderr}`)
    }
  }
}

// Helper to process a file result and collect manual steps
let processFileResult = (
  result: result<Files.fileResult, string>,
  manualSteps: array<string>,
): result<unit, string> => {
  switch result {
  | Ok(fileResult) =>
    Console.log(Files.formatResult(fileResult))
    switch fileResult {
    | Files.ManualEditRequired({details, _}) => manualSteps->Array.push(details)->ignore
    | _ => ()
    }
    Ok()
  | Error(msg) =>
    Console.error(`  ${Style.warn}  ${Style.bold("Error:")} ${msg}`)
    Error(msg)
  }
}

// Collect which files need auto-editing (without prompting the user)
let collectPendingAutoEdits = (
  ~projectDir: string,
  ~host: string,
  ~info: Detect.projectInfo,
  ~isNext16Plus: bool,
): array<Files.pendingAutoEdit> => {
  let pending = []

  // Check middleware or proxy
  switch isNext16Plus {
  | true =>
    switch Files.getPendingAutoEdit(
      ~existingFile=info.proxy,
      ~filePath=Path.join([projectDir, "proxy.ts"]),
      ~fileName="proxy.ts",
      ~fileType=AutoEdit.Proxy,
      ~manualDetails=Templates.ManualInstructions.proxy("proxy.ts", host),
    ) {
    | Some(p) => pending->Array.push(p)->ignore
    | None => ()
    }
  | false =>
    switch Files.getPendingAutoEdit(
      ~existingFile=info.middleware,
      ~filePath=Path.join([projectDir, "middleware.ts"]),
      ~fileName="middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails=Templates.ManualInstructions.middleware("middleware.ts", host),
    ) {
    | Some(p) => pending->Array.push(p)->ignore
    | None => ()
    }
  }

  // Check instrumentation
  let instrFileName = switch info.hasSrcDir {
  | true => "src/instrumentation.ts"
  | false => "instrumentation.ts"
  }
  let instrFilePath = switch info.hasSrcDir {
  | true => Path.join([projectDir, "src", "instrumentation.ts"])
  | false => Path.join([projectDir, "instrumentation.ts"])
  }
  switch Files.getPendingAutoEdit(
    ~existingFile=info.instrumentation,
    ~filePath=instrFilePath,
    ~fileName=instrFileName,
    ~fileType=AutoEdit.Instrumentation,
    ~manualDetails=Templates.ManualInstructions.instrumentation(instrFileName),
  ) {
  | Some(p) => pending->Array.push(p)->ignore
  | None => ()
  }

  pending
}

// Main install function
let run = async (options: installOptions): installResult => {
  let projectDir = options.prefix->Option.getOr(Process.cwd())
  let host = options.server

  Console.log(Templates.banner())
  Console.log(`  ${Style.bullet} ${Style.bold("Server:")}   ${host}`)

  switch options.dryRun {
  | true =>
    Console.log("")
    Console.log(Templates.SuccessMessages.dryRunHeader)
  | false => ()
  }

  // Step 1: Detect project info
  switch await Detect.detect(projectDir) {
  | Error(msg) =>
    Console.error(`  ${Style.warn}  ${Style.bold("Error:")} ${msg}`)
    Failure(msg)

  | Ok(info) =>
    let version = info.nextVersion->Option.map(v => v.raw)->Option.getOr("unknown")
    let isNext16Plus = Detect.isNextJs16Plus(info)

    Console.log(`  ${Style.bullet} ${Style.bold("Detected:")} Next.js ${version}`)
    Console.log("")

    // Step 2: Install dependencies (unless skipped)
    switch options.skipDeps {
    | true => ()
    | false =>
      switch await installDependencies(
        ~projectDir,
        ~packageManager=info.packageManager,
        ~dryRun=options.dryRun,
      ) {
      | Error(msg) =>
        Console.error(`  ${Style.warn}  ${msg}`)
        // Continue anyway - user might have deps already
        ()
      | Ok() => ()
      }
      Console.log("")
    }

    // Step 3: Collect files needing auto-edit and prompt once (if any)
    let pendingEdits = collectPendingAutoEdits(~projectDir, ~host, ~info, ~isNext16Plus)
    let shouldAutoEdit = switch (pendingEdits->Array.length > 0, options.dryRun) {
    | (true, false) =>
      let fileNames = pendingEdits->Array.map(p => p.fileName)
      await AutoEdit.promptUserForAutoEdit(~fileNames)
    | _ => false
    }

    // Step 4: Handle files based on Next.js version
    let manualSteps = []

    // Handle middleware or proxy based on version
    let middlewareResult = switch isNext16Plus {
    | true =>
      await Files.handleProxy(
        ~projectDir,
        ~host,
        ~existingFile=info.proxy,
        ~dryRun=options.dryRun,
        ~autoEdit=shouldAutoEdit,
      )
    | false =>
      await Files.handleMiddleware(
        ~projectDir,
        ~host,
        ~existingFile=info.middleware,
        ~dryRun=options.dryRun,
        ~autoEdit=shouldAutoEdit,
      )
    }

    switch processFileResult(middlewareResult, manualSteps) {
    | Error(msg) => Failure(msg)
    | Ok() =>
      // Handle instrumentation
      let instrumentationResult = await Files.handleInstrumentation(
        ~projectDir,
        ~host,
        ~hasSrcDir=info.hasSrcDir,
        ~existingFile=info.instrumentation,
        ~dryRun=options.dryRun,
        ~autoEdit=shouldAutoEdit,
      )

      switch processFileResult(instrumentationResult, manualSteps) {
      | Error(msg) => Failure(msg)
      | Ok() =>
        // Summary
        switch manualSteps->Array.length > 0 {
        | true =>
          Console.log("")
          Console.log(`  ${Style.divider}`)
          Console.log("")
          Console.log(`  ${Style.yellowBold("Manual steps required:")}`)
          Console.log("")
          manualSteps->Array.forEach(step => Console.log(step))
          Console.log("")
          PartialSuccess({manualStepsRequired: manualSteps})
        | false =>
          switch options.dryRun {
          | true => ()
          | false =>
            let devCommand = Detect.getDevCommand(info.packageManager)
            Console.log("")
            Console.log(`  ${Style.divider}`)
            Console.log(Templates.SuccessMessages.installComplete(~devCommand))
          }
          Success
        }
      }
    }
  }
}
