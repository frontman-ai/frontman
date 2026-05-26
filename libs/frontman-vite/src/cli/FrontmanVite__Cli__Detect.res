// Detection module for Vite project analysis
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module FsUtils = FrontmanAiFrontmanCore.FrontmanCore__FsUtils
module PackageManager = FrontmanAiFrontmanCore.FrontmanCore__Cli__PackageManager

type packageManager = PackageManager.t =
  | Npm
  | Yarn
  | Pnpm
  | Bun
  | Deno

type existingViteConfig =
  | NotFound
  | HasFrontman
  | NeedsFrontman({filePath: string, content: string})

type projectInfo = {
  viteConfig: existingViteConfig,
  packageManager: packageManager,
  viteConfigFileName: string,
}

// Read file content safely
let readFile = async (path: string): option<string> => {
  try {
    let content = await Fs.Promises.readFile(path)
    Some(content)
  } catch {
  | _ => None
  }
}

let detectPackageManager = PackageManager.detect

// Pattern to detect frontman plugin import
let frontmanImportPattern = /@frontman-ai\/vite|frontman-vite|frontmanPlugin/

// Find the vite config file (supports .ts, .js, .mjs, .mts)
let findViteConfig = async (projectDir: string): option<(string, string)> => {
  let candidates = ["vite.config.ts", "vite.config.js", "vite.config.mts", "vite.config.mjs"]

  let rec check = async (remaining: array<string>) => {
    switch remaining->Array.get(0) {
    | None => None
    | Some(fileName) =>
      let filePath = Path.join([projectDir, fileName])
      switch await readFile(filePath) {
      | Some(content) => Some((fileName, content))
      | None =>
        let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))
        await check(rest)
      }
    }
  }

  await check(candidates)
}

// Analyze existing vite config for Frontman
let analyzeViteConfig = async (projectDir: string): (existingViteConfig, string) => {
  switch await findViteConfig(projectDir) {
  | None => (NotFound, "vite.config.ts")
  | Some((fileName, content)) =>
    if frontmanImportPattern->RegExp.test(content) {
      (HasFrontman, fileName)
    } else {
      let filePath = Path.join([projectDir, fileName])
      (NeedsFrontman({filePath, content}), fileName)
    }
  }
}

// Check if package.json exists
let hasPackageJson = async (projectDir: string): bool => {
  await FsUtils.pathExists(Path.join([projectDir, "package.json"]))
}

// Check if this is a Vite project
let hasViteDependency = async (projectDir: string): bool => {
  let pkgPath = Path.join([projectDir, "package.json"])
  switch await readFile(pkgPath) {
  | None => false
  | Some(content) =>
    try {
      let json = JSON.parseOrThrow(content)
      switch json->JSON.Decode.object {
      | None => false
      | Some(obj) =>
        let checkDeps = (key: string) =>
          obj
          ->Dict.get(key)
          ->Option.flatMap(JSON.Decode.object)
          ->Option.mapOr(false, deps => deps->Dict.get("vite")->Option.isSome)
        checkDeps("dependencies") || checkDeps("devDependencies")
      }
    } catch {
    | _ => false
    }
  }
}

// Main detection function
let detect = async (projectDir: string): result<projectInfo, string> => {
  let hasPackage = await hasPackageJson(projectDir)
  switch hasPackage {
  | false => Error("No package.json found. Please run from your Vite project root.")
  | true =>
    let hasVite = await hasViteDependency(projectDir)
    switch hasVite {
    | false => Error("Could not find vite in package.json. Please verify this is a Vite project.")
    | true =>
      let (viteConfig, viteConfigFileName) = await analyzeViteConfig(projectDir)
      let packageManager = await detectPackageManager(projectDir)

      Ok({
        viteConfig,
        packageManager,
        viteConfigFileName,
      })
    }
  }
}

let getPackageManagerCommand = PackageManager.command

let getDevCommand = PackageManager.devCommand

let getInstallArgs = PackageManager.devInstallArgs
