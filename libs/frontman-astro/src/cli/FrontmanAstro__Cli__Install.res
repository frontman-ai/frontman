// Install command implementation
module Bindings = FrontmanBindings
module ChildProcess = Bindings.ChildProcess
module Path = Bindings.Path
module Process = Bindings.Process

module AutoEdit = FrontmanAstro__Cli__AutoEdit
module Detect = FrontmanAstro__Cli__Detect
module Files = FrontmanAstro__Cli__Files
module Templates = FrontmanAstro__Cli__Templates
module Style = FrontmanAstro__Cli__Style

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
  let packages = ["@frontman-ai/astro", "@astrojs/node"]
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
): array<Files.pendingAutoEdit> => {
  let pending = []

  // Check astro config
  switch Files.getPendingAutoEdit(
    ~existingFile=info.config,
    ~filePath=Path.join([projectDir, info.configFileName]),
    ~fileName=info.configFileName,
    ~fileType=AutoEdit.Config,
    ~manualDetails=Templates.ManualInstructions.config(info.configFileName, host),
  ) {
  | Some(p) => pending->Array.push(p)->ignore
  | None => ()
  }

  // Check middleware
  switch Files.getPendingAutoEdit(
    ~existingFile=info.middleware,
    ~filePath=Path.join([projectDir, info.middlewareFileName]),
    ~fileName=info.middlewareFileName,
    ~fileType=AutoEdit.Middleware,
    ~manualDetails=Templates.ManualInstructions.middleware(info.middlewareFileName, host),
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
    let version = (info.astroVersion->Option.getOrThrow).raw

    Console.log(`  ${Style.bullet} ${Style.bold("Detected:")} Astro ${version}`)
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
    let pendingEdits = collectPendingAutoEdits(~projectDir, ~host, ~info)
    let shouldAutoEdit = switch (pendingEdits->Array.length > 0, options.dryRun) {
    | (true, false) =>
      let fileNames = pendingEdits->Array.map(p => p.fileName)
      await AutoEdit.promptUserForAutoEdit(~fileNames)
    | _ => false
    }

    // Step 4: Handle files
    let manualSteps = []

    // Handle astro config
    let configResult = await Files.handleConfig(
      ~projectDir,
      ~host,
      ~configFileName=info.configFileName,
      ~existingFile=info.config,
      ~dryRun=options.dryRun,
      ~autoEdit=shouldAutoEdit,
    )

    switch processFileResult(configResult, manualSteps) {
    | Error(msg) => Failure(msg)
    | Ok() =>
      // Handle middleware
      let middlewareResult = await Files.handleMiddleware(
        ~projectDir,
        ~host,
        ~middlewareFileName=info.middlewareFileName,
        ~existingFile=info.middleware,
        ~dryRun=options.dryRun,
        ~autoEdit=shouldAutoEdit,
      )

      switch processFileResult(middlewareResult, manualSteps) {
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
