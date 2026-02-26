// Detection module for Next.js project analysis
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module FsUtils = FrontmanFrontmanCore.FrontmanCore__FsUtils

type nextVersion = {
  major: int,
  minor: int,
  raw: string,
}

type packageManager =
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
  nextVersion: option<nextVersion>,
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

// Detect Next.js version from node_modules
let detectNextVersion = async (projectDir: string): option<nextVersion> => {
  let nextPkgPath = Path.join([projectDir, "node_modules", "next", "package.json"])

  switch await readFile(nextPkgPath) {
  | None => None
  | Some(content) =>
    try {
      let json = JSON.parseOrThrow(content)
      switch json->JSON.Decode.object->Option.flatMap(obj => obj->Dict.get("version")) {
      | Some(JSON.String(version)) =>
        // Parse version like "15.0.0" or "16.0.0-canary.1"
        let parts = version->String.split(".")
        switch (parts->Array.get(0), parts->Array.get(1)) {
        | (Some(majorStr), Some(minorStr)) =>
          let major = majorStr->Int.fromString->Option.getOr(0)
          // Handle minor with potential suffixes like "0-canary"
          let minorClean = minorStr->String.split("-")->Array.get(0)->Option.getOr("0")
          let minor = minorClean->Int.fromString->Option.getOr(0)
          Some({major, minor, raw: version})
        | _ => None
        }
      | _ => None
      }
    } catch {
    | _ => None
    }
  }
}

// Detect package manager from lock files
// Checks current directory and parent directories (for monorepo setups)
let detectPackageManager = async (projectDir: string): packageManager => {
  // Check a directory for lock files
  let checkDir = async (dir: string): option<packageManager> => {
    let bunLockb = Path.join([dir, "bun.lockb"])
    let bunLock = Path.join([dir, "bun.lock"])
    let denoLock = Path.join([dir, "deno.lock"])
    let pnpmLock = Path.join([dir, "pnpm-lock.yaml"])
    let yarnLock = Path.join([dir, "yarn.lock"])
    let npmLock = Path.join([dir, "package-lock.json"])

    if (await FsUtils.pathExists(bunLockb)) || (await FsUtils.pathExists(bunLock)) {
      Some(Bun)
    } else if await FsUtils.pathExists(denoLock) {
      Some(Deno)
    } else if await FsUtils.pathExists(pnpmLock) {
      Some(Pnpm)
    } else if await FsUtils.pathExists(yarnLock) {
      Some(Yarn)
    } else if await FsUtils.pathExists(npmLock) {
      Some(Npm)
    } else {
      None
    }
  }

  // First check the project directory
  switch await checkDir(projectDir) {
  | Some(pm) => pm
  | None =>
    // Check parent directory (for monorepo setups)
    let parentDir = Path.dirname(projectDir)
    if parentDir != projectDir {
      switch await checkDir(parentDir) {
      | Some(pm) => pm
      | None =>
        // Check grandparent (for deeply nested monorepos)
        let grandparentDir = Path.dirname(parentDir)
        if grandparentDir != parentDir {
          switch await checkDir(grandparentDir) {
          | Some(pm) => pm
          | None => Npm // Default to npm
          }
        } else {
          Npm
        }
      }
    } else {
      Npm // Default to npm
    }
  }
}

// Pattern to detect @frontman-ai/nextjs import
let frontmanImportPattern = %re("/@frontman-ai\/nextjs/")

// Pattern to extract host from createMiddleware config
let hostPattern = %re("/host:\s*['\"]([^'\"]+)['\"]/")

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
  if !hasPackage {
    Error("No package.json found. Please run from your Next.js project root.")
  } else {
    // Detect Next.js version
    let nextVersion = await detectNextVersion(projectDir)

    if nextVersion->Option.isNone {
      Error(
        "Could not find Next.js in node_modules. Please run 'npm install' first or verify this is a Next.js project.",
      )
    } else {
      // Detect existing files
      let middlewarePath = Path.join([projectDir, "middleware.ts"])
      let proxyPath = Path.join([projectDir, "proxy.ts"])

      // Check for instrumentation in both root and src/
      let hasSrcDir = await detectSrcDir(projectDir)
      let instrumentationPath = if hasSrcDir {
        Path.join([projectDir, "src", "instrumentation.ts"])
      } else {
        Path.join([projectDir, "instrumentation.ts"])
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
  switch info.nextVersion {
  | Some({major}) => major >= 16
  | None => false
  }
}

// Get package manager command
// Uses npx to ensure the package manager is available even if not in PATH
let getPackageManagerCommand = (pm: packageManager): string => {
  switch pm {
  | Npm => "npm"
  | Yarn => "npx yarn"
  | Pnpm => "npx pnpm"
  | Bun => "bun"
  | Deno => "deno"
  }
}

// Get the dev server command for display in success messages
let getDevCommand = (pm: packageManager): string => {
  switch pm {
  | Npm => "npm run dev"
  | Yarn => "yarn dev"
  | Pnpm => "pnpm dev"
  | Bun => "bun dev"
  | Deno => "deno task dev"
  }
}

// Get install command args for each package manager
// Installs as devDependencies: Next.js bundles all imports at build time (both
// middleware on Edge and instrumentation on Node.js), so these packages only need
// to exist during `next build`, not at runtime. Every deployment platform runs
// `npm install` (all deps) before `next build`, then prunes devDeps afterward.
let getInstallArgs = (pm: packageManager): array<string> => {
  switch pm {
  | Npm => ["install", "-D"]
  | Yarn => ["add", "-D"]
  | Pnpm => ["add", "--save-dev"]
  | Bun => ["add", "--dev"]
  | Deno => ["add", "--dev"]
  }
}
