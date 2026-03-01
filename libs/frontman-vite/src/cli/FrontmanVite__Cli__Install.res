// Install command implementation for Vite
module Bindings = FrontmanBindings
module ChildProcess = FrontmanFrontmanCore.FrontmanCore__ChildProcess
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process

module Detect = FrontmanVite__Cli__Detect
module Templates = FrontmanVite__Cli__Templates
module Style = FrontmanVite__Cli__Style

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
  let packages = ["@frontman-ai/vite"]
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

// Inject frontmanPlugin into an existing vite config file
// Strategy: add import at the top, add frontmanPlugin({ host }) to plugins array
let injectFrontmanPlugin = (~server: string, content: string): result<string, string> => {
  // Check if plugins array exists
  let pluginsPattern = %re("/plugins\s*:\s*\[/")

  switch pluginsPattern->RegExp.test(content) {
  | false => Error("Could not find a `plugins: [` array in your Vite config")
  | true =>
    // Add import at the top of the file (after any existing imports)
    let importStatement = Templates.importLine ++ "\n"

    // Find the last import line to insert after
    let lines = content->String.split("\n")
    let lastImportIdx = ref(-1)

    lines->Array.forEachWithIndex((line, idx) => {
      let trimmed = line->String.trim
      switch trimmed->String.startsWith("import ") || trimmed->String.startsWith("import{") {
      | true => lastImportIdx := idx
      | false => ()
      }
    })

    let contentWithImport = switch lastImportIdx.contents >= 0 {
    | true =>
      let before =
        lines->Array.slice(~start=0, ~end=lastImportIdx.contents + 1)->Array.join("\n")
      let after =
        lines
        ->Array.slice(~start=lastImportIdx.contents + 1, ~end=Array.length(lines))
        ->Array.join("\n")
      before ++ "\n" ++ importStatement ++ after
    | false =>
      // No imports found, add at the very top
      importStatement ++ "\n" ++ content
    }

    // Insert frontmanPlugin({ host }) as first item in plugins array
    let call = Templates.pluginCall(~server)
    let result =
      contentWithImport->String.replaceRegExp(
        %re("/plugins\s*:\s*\[/"),
        `plugins: [\n    ${call},`,
      )

    Ok(result)
  }
}

// Handle vite config file
let handleViteConfig = async (
  ~projectDir: string,
  ~info: Detect.projectInfo,
  ~server: string,
  ~dryRun: bool,
): result<unit, string> => {
  switch info.viteConfig {
  | Detect.HasFrontman =>
    Console.log(Templates.SuccessMessages.fileSkipped(info.viteConfigFileName))
    Ok()

  | Detect.NotFound =>
    // No vite config at all — create one from scratch
    let fileName = "vite.config.ts"
    let filePath = Path.join([projectDir, fileName])
    let call = Templates.pluginCall(~server)
    let content = `import { defineConfig } from 'vite';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  plugins: [
    ${call},
  ],
});
`
    switch dryRun {
    | true =>
      Console.log(`  ${Style.dim(`Would create: ${fileName}`)}`)
      Ok()
    | false =>
      await Fs.Promises.writeFile(filePath, content)
      Console.log(Templates.SuccessMessages.fileCreated(fileName))
      Ok()
    }

  | Detect.NeedsFrontman({filePath, content}) =>
    switch dryRun {
    | true =>
      Console.log(`  ${Style.dim(`Would modify: ${info.viteConfigFileName}`)}`)
      Ok()
    | false =>
      switch injectFrontmanPlugin(~server, content) {
      | Ok(newContent) =>
        await Fs.Promises.writeFile(filePath, newContent)
        Console.log(Templates.SuccessMessages.fileUpdated(info.viteConfigFileName))
        Ok()
      | Error(_) =>
        Console.log(Templates.SuccessMessages.manualEditRequired(info.viteConfigFileName))
        Error(Templates.ManualInstructions.viteConfig(~server, info.viteConfigFileName))
      }
    }
  }
}

// Main install function
let run = async (options: installOptions): installResult => {
  let projectDir = options.prefix->Option.getOr(Process.cwd())

  Console.log(Templates.banner())
  Console.log(`  ${Style.bullet} ${Style.bold("Server:")}   ${options.server}`)

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
    Console.log(`  ${Style.bullet} ${Style.bold("Detected:")} Vite project`)
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
        ()
      | Ok() => ()
      }
      Console.log("")
    }

    // Step 3: Handle vite config
    let manualSteps = []

    switch await handleViteConfig(~projectDir, ~info, ~server=options.server, ~dryRun=options.dryRun) {
    | Ok() => ()
    | Error(details) => manualSteps->Array.push(details)->ignore
    }

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
        Console.log(Templates.SuccessMessages.installComplete(~devCommand, ~port="5173"))
      }
      Success
    }
  }
}
