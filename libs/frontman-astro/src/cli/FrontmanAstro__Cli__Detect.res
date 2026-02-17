// Detection module for Astro project analysis
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

type astroVersion = {
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
  astroVersion: option<astroVersion>,
  config: existingFile,
  middleware: existingFile,
  configFileName: string,
  middlewareFileName: string,
  packageManager: packageManager,
}

// Check if a file exists
let fileExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    true
  } catch {
  | _ => false
  }
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

// Schema for the minimal astro package.json we need
@schema
type astroPkgJson = {version: string}

// Detect Astro version from node_modules
let detectAstroVersion = async (projectDir: string): option<astroVersion> => {
  let astroPkgPath = Path.join([projectDir, "node_modules", "astro", "package.json"])

  switch await readFile(astroPkgPath) {
  | None => None
  | Some(content) =>
    try {
      let pkg = S.parseJsonStringOrThrow(content, astroPkgJsonSchema)
      let version = pkg.version
      // Parse version like "5.0.0" or "5.1.0-beta.1"
      let parts = version->String.split(".")
      switch (parts->Array.get(0), parts->Array.get(1)) {
      | (Some(majorStr), Some(minorStr)) =>
        let major = majorStr->Int.fromString->Option.getOrThrow
        // Handle minor with potential suffixes like "0-beta"
        let minorClean = minorStr->String.split("-")->Array.getUnsafe(0)
        let minor = minorClean->Int.fromString->Option.getOrThrow
        Some({major, minor, raw: version})
      | _ => None
      }
    } catch {
    | _ => None
    }
  }
}

// Detect which astro config file variant exists
// Checks: astro.config.mjs, astro.config.ts, astro.config.mts, astro.config.js
let detectConfigFile = async (projectDir: string): option<string> => {
  let variants = ["astro.config.mjs", "astro.config.ts", "astro.config.mts", "astro.config.js"]

  let rec check = async (remaining: array<string>) => {
    switch remaining->Array.get(0) {
    | None => None
    | Some(name) =>
      let path = Path.join([projectDir, name])
      switch await fileExists(path) {
      | true => Some(name)
      | false =>
        let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))
        await check(rest)
      }
    }
  }

  await check(variants)
}

// Pattern to detect @frontman-ai/astro (or legacy @frontman/frontman-astro) import
let frontmanImportPattern = %re("/@frontman-ai\/astro|@frontman\/frontman-astro|frontman-astro\/integration/")

// Pattern to extract host from makeConfig or createMiddleware config
let hostPattern = %re("/host:\s*['\"]([^'\"]+)['\"]/")

// Analyze an existing file for Frontman configuration
let analyzeFile = async (filePath: string): existingFile => {
  switch await readFile(filePath) {
  | None => NotFound
  | Some(content) =>
    // Check if it imports @frontman-ai/astro (or legacy @frontman/frontman-astro)
    switch frontmanImportPattern->RegExp.test(content) {
    | true =>
      // Try to extract the host
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
    | false => NeedsManualEdit
    }
  }
}

// Detect package manager from lock files
// Checks current directory and parent directories (for monorepo setups)
let detectPackageManager = async (projectDir: string): packageManager => {
  // Check a directory for lock files, in priority order
  let checkDir = async (dir: string): option<packageManager> => {
    let lockFiles = [
      (Path.join([dir, "bun.lockb"]), Bun),
      (Path.join([dir, "bun.lock"]), Bun),
      (Path.join([dir, "deno.lock"]), Deno),
      (Path.join([dir, "pnpm-lock.yaml"]), Pnpm),
      (Path.join([dir, "yarn.lock"]), Yarn),
      (Path.join([dir, "package-lock.json"]), Npm),
    ]

    let rec check = async (remaining: array<(string, packageManager)>) => {
      switch remaining->Array.get(0) {
      | None => None
      | Some((path, pm)) =>
        switch await fileExists(path) {
        | true => Some(pm)
        | false =>
          let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))
          await check(rest)
        }
      }
    }

    await check(lockFiles)
  }

  // Check project dir, then parent, then grandparent (monorepo support)
  let dirsToCheck = {
    let parentDir = Path.dirname(projectDir)
    let grandparentDir = Path.dirname(parentDir)
    [projectDir, parentDir, grandparentDir]->Array.filter(d => d != projectDir || d == projectDir)
  }

  // Deduplicate (e.g. at filesystem root, dirname("/") == "/")
  let uniqueDirs = {
    let seen = Dict.make()
    dirsToCheck->Array.filter(d => {
      switch seen->Dict.get(d) {
      | Some(_) => false
      | None =>
        seen->Dict.set(d, true)
        true
      }
    })
  }

  let rec tryDirs = async (remaining: array<string>) => {
    switch remaining->Array.get(0) {
    | None => Npm // Default to npm
    | Some(dir) =>
      switch await checkDir(dir) {
      | Some(pm) => pm
      | None =>
        let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))
        await tryDirs(rest)
      }
    }
  }

  await tryDirs(uniqueDirs)
}

// Check if package.json exists (validates this is a project root)
let hasPackageJson = async (projectDir: string): bool => {
  await fileExists(Path.join([projectDir, "package.json"]))
}

// Main detection function
let detect = async (projectDir: string): result<projectInfo, string> => {
  // First verify this is a project directory
  let hasPackage = await hasPackageJson(projectDir)
  switch hasPackage {
  | false => Error("No package.json found. Please run from your Astro project root.")
  | true =>
    // Detect Astro version
    let astroVersion = await detectAstroVersion(projectDir)

    switch astroVersion {
    | None =>
      Error(
        "Could not find Astro in node_modules. Please run 'npm install' first or verify this is an Astro project.",
      )
    | Some(_) =>
      // Detect config file
      let configFileName = switch await detectConfigFile(projectDir) {
      | Some(name) => name
      | None => "astro.config.mjs" // Default for creation
      }

      let configPath = Path.join([projectDir, configFileName])
      let config = await analyzeFile(configPath)

      // Detect middleware file (check src/middleware.ts and src/middleware.js)
      let middlewareTsPath = Path.join([projectDir, "src", "middleware.ts"])
      let middlewareJsPath = Path.join([projectDir, "src", "middleware.js"])

      let (middleware, middlewareFileName) = switch await fileExists(middlewareTsPath) {
      | true => (await analyzeFile(middlewareTsPath), "src/middleware.ts")
      | false =>
        switch await fileExists(middlewareJsPath) {
        | true => (await analyzeFile(middlewareJsPath), "src/middleware.js")
        | false => (NotFound, "src/middleware.ts") // Default for creation
        }
      }

      // Detect package manager
      let packageManager = await detectPackageManager(projectDir)

      Ok({
        astroVersion,
        config,
        middleware,
        configFileName,
        middlewareFileName,
        packageManager,
      })
    }
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
let getInstallArgs = (pm: packageManager, ~isDev: bool=false): array<string> => {
  switch (pm, isDev) {
  | (Npm, true) => ["install", "-D"]
  | (Npm, false) => ["install"]
  | (Yarn, true) => ["add", "-D"]
  | (Yarn, false) => ["add"]
  | (Pnpm, true) => ["add", "--save-dev"]
  | (Pnpm, false) => ["add"]
  | (Bun, true) | (Deno, true) => ["add", "--dev"]
  | (Bun, false) | (Deno, false) => ["add"]
  }
}
