// Detection module for Next.js project analysis
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module FsUtils = FrontmanAiFrontmanCore.FrontmanCore__FsUtils
module ExnUtils = FrontmanAiFrontmanCore.FrontmanCore__ExnUtils
module Semver = FrontmanAiFrontmanCore.FrontmanCore__Semver
module PackageManager = FrontmanAiFrontmanCore.FrontmanCore__Cli__PackageManager

// Node.js module resolution — handles monorepo hoisting, pnpm virtual store,
// Yarn PnP, and all standard node_modules layouts.
type nodeRequire = {resolve: string => string}
@module("node:module")
external createRequire: string => nodeRequire = "createRequire"

type nextVersion = {
  major: int,
  minor: int,
  raw: string,
}

type packageManager = PackageManager.t =
  | Npm
  | Yarn
  | Pnpm
  | Bun
  | Deno

type existingFile =
  | NotFound
  | HasFrontman({host: string})
  | NeedsManualEdit

type projectInfo = {
  nextVersion: nextVersion,
  middleware: existingFile,
  proxy: existingFile,
  instrumentation: existingFile,
  hasSrcDir: bool,
  packageManager: packageManager,
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

// Resolve a module from a given directory using Node.js module resolution.
// Handles monorepo hoisting (Yarn/npm/pnpm workspaces), symlinks, and
// non-standard layouts like pnpm's virtual store.
// Returns Error with the specific exception message on failure.
let resolveFrom = (dir: string, moduleId: string): result<string, string> => {
  try {
    let req = createRequire(Path.join([dir, "package.json"]))
    Ok(req.resolve(moduleId))
  } catch {
  | exn => Error(`Could not resolve "${moduleId}" from ${dir}: ${ExnUtils.message(exn)}`)
  }
}

// Partial package.json schema — only the fields we need to check for next.
@schema
type packageJsonDeps = {
  dependencies: option<Dict.t<string>>,
  devDependencies: option<Dict.t<string>>,
}

// Sury schema for reading the version field from next/package.json.
@schema
type nextPackageJson = {version: string}

// Check if this project declares next as a direct dependency.
// Prevents false detection in monorepo sibling workspaces where next
// is resolvable via hoisted node_modules but belongs to a different workspace.
let hasNextDependency = async (projectDir: string): bool => {
  let pkgPath = Path.join([projectDir, "package.json"])
  switch await readFile(pkgPath) {
  | None => false
  | Some(content) =>
    try {
      let pkg = S.parseJsonStringOrThrow(content, packageJsonDepsSchema)
      let hasDep =
        pkg.dependencies->Option.mapOr(false, deps => deps->Dict.get("next")->Option.isSome)
      let hasDevDep =
        pkg.devDependencies->Option.mapOr(false, deps => deps->Dict.get("next")->Option.isSome)
      hasDep || hasDevDep
    } catch {
    | exn =>
      Console.warn(`Warning: failed to parse ${pkgPath}: ${ExnUtils.message(exn)}`)
      false
    }
  }
}

// Detect Next.js version using Node.js module resolution.
// First verifies that next is declared in this project's package.json,
// then uses createRequire to resolve the actual installed version.
// This correctly finds Next.js when dependencies are hoisted to a parent
// directory (monorepo workspaces) while avoiding false positives from
// sibling workspaces.
let detectNextVersion = async (projectDir: string): result<nextVersion, string> => {
  let hasNext = await hasNextDependency(projectDir)
  switch hasNext {
  | false => Error("next is not listed as a dependency in package.json")
  | true =>
    switch resolveFrom(projectDir, "next/package.json") {
    | Error(msg) => Error(msg)
    | Ok(resolvedPath) =>
      switch await readFile(resolvedPath) {
      | None => Error(`Could not read ${resolvedPath}`)
      | Some(content) =>
        try {
          let pkg = S.parseJsonStringOrThrow(content, nextPackageJsonSchema)
          switch Semver.parse(pkg.version) {
          | None => Error(`Could not parse version "${pkg.version}"`)
          | Some(sv) => Ok({major: sv.major, minor: sv.minor, raw: pkg.version})
          }
        } catch {
        | exn => Error(`Failed to parse next/package.json: ${ExnUtils.message(exn)}`)
        }
      }
    }
  }
}

let detectPackageManager = PackageManager.detect

// Pattern to detect @frontman-ai/nextjs import
let frontmanImportPattern = /@frontman-ai\/nextjs/

// Pattern to extract host from createMiddleware config
let hostPattern = /host:\s*['\"]([^'\"]+)['\"]/

// Analyze an existing file for Frontman configuration
let analyzeFile = async (filePath: string): existingFile => {
  switch await readFile(filePath) {
  | None => NotFound
  | Some(content) =>
    // Check if it imports @frontman-ai/nextjs
    if frontmanImportPattern->RegExp.test(content) {
      // Try to extract the host
      // Note: RegExp.Result.matches does .slice(1), so capture groups start at index 0
      switch hostPattern->RegExp.exec(content) {
      | Some(result) =>
        let maybeHost =
          result
          ->RegExp.Result.matches
          ->Array.get(0) // First capture group after slice(1)
          ->Option.flatMap(x => x)
        switch maybeHost {
        | Some(host) => HasFrontman({host: host})
        | None => HasFrontman({host: ""})
        }
      | None => HasFrontman({host: ""})
      }
    } else {
      NeedsManualEdit
    }
  }
}

// Detect if src/ directory exists
let detectSrcDir = async (projectDir: string): bool => {
  await FsUtils.dirExists(Path.join([projectDir, "src"]))
}

// Check if package.json exists (validates this is a project root)
let hasPackageJson = async (projectDir: string): bool => {
  await FsUtils.pathExists(Path.join([projectDir, "package.json"]))
}

// Main detection function
let detect = async (projectDir: string): result<projectInfo, string> => {
  // First verify this is a project directory
  let hasPackage = await hasPackageJson(projectDir)
  switch hasPackage {
  | false => Error("No package.json found. Please run from your Next.js project root.")
  | true =>
    switch await detectNextVersion(projectDir) {
    | Error(msg) => Error(msg)
    | Ok(nextVersion) =>
      // Detect existing files
      let middlewarePath = Path.join([projectDir, "middleware.ts"])
      let proxyPath = Path.join([projectDir, "proxy.ts"])

      // Check for instrumentation in both root and src/
      let hasSrcDir = await detectSrcDir(projectDir)
      let instrumentationPath = switch hasSrcDir {
      | true => Path.join([projectDir, "src", "instrumentation.ts"])
      | false => Path.join([projectDir, "instrumentation.ts"])
      }

      let middleware = await analyzeFile(middlewarePath)
      let proxy = await analyzeFile(proxyPath)
      let instrumentation = await analyzeFile(instrumentationPath)

      // Detect package manager
      let packageManager = await detectPackageManager(projectDir)

      Ok({
        nextVersion,
        middleware,
        proxy,
        instrumentation,
        hasSrcDir,
        packageManager,
      })
    }
  }
}

// Helper to check if this is Next.js 16+
let isNextJs16Plus = (info: projectInfo): bool => {
  info.nextVersion.major >= 16
}

let getPackageManagerCommand = PackageManager.command

let getDevCommand = PackageManager.devCommand

let getInstallArgs = PackageManager.devInstallArgs
