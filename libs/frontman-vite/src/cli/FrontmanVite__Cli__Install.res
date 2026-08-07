module Bindings = FrontmanBindings
module ChildProcess = FrontmanAiFrontmanCore.FrontmanCore__ChildProcess
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process

module Detect = FrontmanVite__Cli__Detect
module Templates = FrontmanVite__Cli__Templates
module Style = FrontmanVite__Cli__Style
module PackageManager = FrontmanAiFrontmanCore.FrontmanCore__Cli__PackageManager

type installOptions = {
  server: string,
  prefix: option<string>,
  dryRun: bool,
  skipDeps: bool,
}

type installResult =
  | Success
  | PartialSuccess({@live manualStepsRequired: array<string>})
  | Failure(string)

let installDependencies = async (
  ~projectDir: string,
  ~packageManager: Detect.packageManager,
  ~dryRun: bool,
): result<unit, string> => {
  let pm = Detect.getPackageManagerCommand(packageManager)
  let args = Detect.getInstallArgs(packageManager)
  let packages = ["@frontman-ai/vite"]
  let packages = PackageManager.npmPackages(packageManager, packages)
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

let injectFrontmanPlugin = (~server: string, content: string): result<string, string> => {
  let pluginsPattern = /plugins\s*:\s*\[/

  switch pluginsPattern->RegExp.test(content) {
  | false => Error("Could not find a `plugins: [` array in your Vite config")
  | true =>
    let importStatement = Templates.importLine ++ "\n"

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
      let before = lines->Array.slice(~start=0, ~end=lastImportIdx.contents + 1)->Array.join("\n")
      let after =
        lines
        ->Array.slice(~start=lastImportIdx.contents + 1, ~end=Array.length(lines))
        ->Array.join("\n")
      before ++ "\n" ++ importStatement ++ after
    | false => importStatement ++ "\n" ++ content
    }

    let call = Templates.pluginCall(~server)
    let result =
      contentWithImport->String.replaceRegExp(/plugins\s*:\s*\[/, `plugins: [\n    ${call},`)

    Ok(result)
  }
}

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

  switch await Detect.detect(projectDir) {
  | Error(msg) =>
    Console.error(`  ${Style.warn}  ${Style.bold("Error:")} ${msg}`)
    Failure(msg)

  | Ok(info) =>
    Console.log(`  ${Style.bullet} ${Style.bold("Detected:")} Vite project`)
    Console.log("")

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

    let manualSteps = []

    switch await handleViteConfig(
      ~projectDir,
      ~info,
      ~server=options.server,
      ~dryRun=options.dryRun,
    ) {
    | Ok() => ()
    | Error(details) => manualSteps->Array.push(details)->ignore
    }

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
        Console.log(
          Templates.SuccessMessages.installComplete(
            ~devCommand,
            ~port="5173",
            ~server=options.server,
          ),
        )
      }
      Success
    }
  }
}
