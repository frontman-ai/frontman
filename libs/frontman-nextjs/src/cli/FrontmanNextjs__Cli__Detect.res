module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module FsUtils = FrontmanAiFrontmanCore.FrontmanCore__FsUtils
module ExnUtils = FrontmanAiFrontmanCore.FrontmanCore__ExnUtils
module Semver = FrontmanAiFrontmanCore.FrontmanCore__Semver
module PackageManager = FrontmanAiFrontmanCore.FrontmanCore__Cli__PackageManager

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

let readFile = async (path: string): option<string> => {
  try {
    let content = await Fs.Promises.readFile(path)
    Some(content)
  } catch {
  | _ => None
  }
}

let resolveFrom = (dir: string, moduleId: string): result<string, string> => {
  try {
    let req = createRequire(Path.join([dir, "package.json"]))
    Ok(req.resolve(moduleId))
  } catch {
  | exn => Error(`Could not resolve "${moduleId}" from ${dir}: ${ExnUtils.message(exn)}`)
  }
}

@schema
type packageJsonDeps = {
  dependencies: option<Dict.t<string>>,
  devDependencies: option<Dict.t<string>>,
}

@schema
type nextPackageJson = {version: string}

let hasNextDependency = async (projectDir: string): bool => {
  let pkgPath = Path.join([projectDir, "package.json"])
  switch await readFile(pkgPath) {
  | None => false
  | Some(content) =>
    try {
      let pkg = content->S.decodeOrThrow(~from=S.jsonString, ~to=packageJsonDepsSchema)
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
          let pkg = content->S.decodeOrThrow(~from=S.jsonString, ~to=nextPackageJsonSchema)
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

let frontmanImportPattern = /@frontman-ai\/nextjs/

let hostPattern = /host:\s*['\"]([^'\"]+)['\"]/

let analyzeFile = async (filePath: string): existingFile => {
  switch await readFile(filePath) {
  | None => NotFound
  | Some(content) =>
    if frontmanImportPattern->RegExp.test(content) {
      switch hostPattern->RegExp.exec(content) {
      | Some(result) =>
        let maybeHost =
          result
          ->RegExp.Result.matches
          ->Array.get(0)
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

let detectSrcDir = async (projectDir: string): bool => {
  let hasSrcApp = await FsUtils.dirExists(Path.join([projectDir, "src", "app"]))
  switch hasSrcApp {
  | true => true
  | false => await FsUtils.dirExists(Path.join([projectDir, "src", "pages"]))
  }
}

let hasPackageJson = async (projectDir: string): bool => {
  await FsUtils.pathExists(Path.join([projectDir, "package.json"]))
}

let detect = async (projectDir: string): result<projectInfo, string> => {
  let hasPackage = await hasPackageJson(projectDir)
  switch hasPackage {
  | false => Error("No package.json found. Please run from your Next.js project root.")
  | true =>
    switch await detectNextVersion(projectDir) {
    | Error(msg) => Error(msg)
    | Ok(nextVersion) =>
      let hasSrcDir = await detectSrcDir(projectDir)
      let entrypointDir = switch hasSrcDir {
      | true => Path.join([projectDir, "src"])
      | false => projectDir
      }
      let middlewarePath = Path.join([entrypointDir, "middleware.ts"])
      let proxyPath = Path.join([entrypointDir, "proxy.ts"])

      let instrumentationPath = switch hasSrcDir {
      | true => Path.join([projectDir, "src", "instrumentation.ts"])
      | false => Path.join([projectDir, "instrumentation.ts"])
      }

      let middleware = await analyzeFile(middlewarePath)
      let proxy = await analyzeFile(proxyPath)
      let instrumentation = await analyzeFile(instrumentationPath)

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

let isNextJs16Plus = (info: projectInfo): bool => {
  info.nextVersion.major >= 16
}

let isSupportedNextJs = (info: projectInfo): bool => {
  switch (info.nextVersion.major, info.nextVersion.minor) {
  | (15, minor) => minor >= 5
  | (major, _) => major >= 16
  }
}

let getPackageManagerCommand = PackageManager.command

let getDevCommand = PackageManager.devCommand

let getInstallArgs = PackageManager.devInstallArgs
