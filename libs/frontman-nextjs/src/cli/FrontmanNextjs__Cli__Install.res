// Install command implementation
module Bindings = FrontmanBindings
module ChildProcess = Bindings.ChildProcess
module Process = Bindings.Process

module Detect = FrontmanNextjs__Cli__Detect
module Files = FrontmanNextjs__Cli__Files
module Templates = FrontmanNextjs__Cli__Templates

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
  let cmd = `${pm} ${args->Array.join(" ")} ${packages->Array.join(" ")}`

  if dryRun {
    Console.log(`Would run: ${cmd}`)
    Ok()
  } else {
    Console.log(`Installing dependencies with ${pm}...`)

    switch await ChildProcess.execWithOptions(cmd, {cwd: projectDir}) {
    | Ok(_) =>
      Console.log("Dependencies installed successfully")
      Ok()
    | Error(err) =>
      let stderr = if err.stderr == "" { "Unknown error" } else { err.stderr }
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
    if Files.isManualEditRequired(fileResult) {
      switch fileResult {
      | Files.ManualEditRequired(msg) => manualSteps->Array.push(msg)->ignore
      | _ => ()
      }
    }
    Ok()
  | Error(msg) =>
    Console.error(`Error: ${msg}`)
    Error(msg)
  }
}

// Main install function
let run = async (options: installOptions): installResult => {
  let projectDir = options.prefix->Option.getOr(Process.cwd())
  let host = options.server

  Console.log("")
  Console.log("  Frontman Installer")
  Console.log(`  Server: ${host}`)
  Console.log("")

  if options.dryRun {
    Console.log(Templates.SuccessMessages.dryRunHeader)
  }

  // Step 1: Detect project info
  switch await Detect.detect(projectDir) {
  | Error(msg) =>
    Console.error(`Error: ${msg}`)
    Failure(msg)

  | Ok(info) =>
    let version = info.nextVersion->Option.map(v => v.raw)->Option.getOr("unknown")
    let isNext16Plus = Detect.isNextJs16Plus(info)

    Console.log(`Detected Next.js ${version}`)
    Console.log("")

    // Step 2: Install dependencies (unless skipped)
    if !options.skipDeps {
      switch await installDependencies(
        ~projectDir,
        ~packageManager=info.packageManager,
        ~dryRun=options.dryRun,
      ) {
      | Error(msg) =>
        Console.error(msg)
        // Continue anyway - user might have deps already
        ()
      | Ok() => ()
      }
    }

    // Step 3: Handle files based on Next.js version
    let manualSteps = []

    // Handle middleware or proxy based on version
    let middlewareResult = if isNext16Plus {
      await Files.handleProxy(
        ~projectDir,
        ~host,
        ~existingFile=info.proxy,
        ~dryRun=options.dryRun,
      )
    } else {
      await Files.handleMiddleware(
        ~projectDir,
        ~host,
        ~existingFile=info.middleware,
        ~dryRun=options.dryRun,
      )
    }

    switch processFileResult(middlewareResult, manualSteps) {
    | Error(msg) => Failure(msg)
    | Ok() =>
      // Handle instrumentation
      let instrumentationResult = await Files.handleInstrumentation(
        ~projectDir,
        ~hasSrcDir=info.hasSrcDir,
        ~existingFile=info.instrumentation,
        ~dryRun=options.dryRun,
      )

      switch processFileResult(instrumentationResult, manualSteps) {
      | Error(msg) => Failure(msg)
      | Ok() =>
        // Summary
        if manualSteps->Array.length > 0 {
          Console.log("")
          Console.log("Manual steps required:")
          manualSteps->Array.forEach(step => Console.log(step))
          PartialSuccess({manualStepsRequired: manualSteps})
        } else {
          if !options.dryRun {
            Console.log(Templates.SuccessMessages.installComplete(host))
          }
          Success
        }
      }
    }
  }
}
