// Detection module for Vite project analysis
module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path

type packageManager =
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

// Detect package manager from lock files
let detectPackageManager = async (projectDir: string): packageManager => {
  let checkDir = async (dir: string): option<packageManager> => {
    let bunLockb = Path.join([dir, "bun.lockb"])
    let bunLock = Path.join([dir, "bun.lock"])
    let denoLock = Path.join([dir, "deno.lock"])
    let pnpmLock = Path.join([dir, "pnpm-lock.yaml"])
    let yarnLock = Path.join([dir, "yarn.lock"])
    let npmLock = Path.join([dir, "package-lock.json"])

    switch true {
    | _ if (await fileExists(bunLockb)) || (await fileExists(bunLock)) => Some(Bun)
    | _ if await fileExists(denoLock) => Some(Deno)
    | _ if await fileExists(pnpmLock) => Some(Pnpm)
    | _ if await fileExists(yarnLock) => Some(Yarn)
    | _ if await fileExists(npmLock) => Some(Npm)
    | _ => None
    }
  }

  switch await checkDir(projectDir) {
  | Some(pm) => pm
  | None =>
    let parentDir = Path.dirname(projectDir)
    switch parentDir != projectDir {
    | true =>
      switch await checkDir(parentDir) {
      | Some(pm) => pm
      | None =>
        let grandparentDir = Path.dirname(parentDir)
        switch grandparentDir != parentDir {
        | true =>
          switch await checkDir(grandparentDir) {
          | Some(pm) => pm
          | None => Npm
          }
        | false => Npm
        }
      }
    | false => Npm
    }
  }
}

// Pattern to detect frontman plugin import
let frontmanImportPattern = %re("/@frontman-ai\/vite|frontman-vite|frontmanPlugin/")

// Find the vite config file (supports .ts, .js, .mjs, .mts)
let findViteConfig = async (projectDir: string): option<(string, string)> => {
  let candidates = [
    "vite.config.ts",
    "vite.config.js",
    "vite.config.mts",
    "vite.config.mjs",
  ]

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
    switch frontmanImportPattern->RegExp.test(content) {
    | true => (HasFrontman, fileName)
    | false =>
      let filePath = Path.join([projectDir, fileName])
      (NeedsFrontman({filePath, content}), fileName)
    }
  }
}

// Check if package.json exists
let hasPackageJson = async (projectDir: string): bool => {
  await fileExists(Path.join([projectDir, "package.json"]))
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
    | false =>
      Error("Could not find vite in package.json. Please verify this is a Vite project.")
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

// Get package manager command
let getPackageManagerCommand = (pm: packageManager): string => {
  switch pm {
  | Npm => "npm"
  | Yarn => "npx yarn"
  | Pnpm => "npx pnpm"
  | Bun => "bun"
  | Deno => "deno"
  }
}

// Get the dev server command
let getDevCommand = (pm: packageManager): string => {
  switch pm {
  | Npm => "npm run dev"
  | Yarn => "yarn dev"
  | Pnpm => "pnpm dev"
  | Bun => "bun dev"
  | Deno => "deno task dev"
  }
}

// Get install command args
let getInstallArgs = (pm: packageManager): array<string> => {
  switch pm {
  | Npm => ["install", "-D"]
  | Yarn => ["add", "-D"]
  | Pnpm => ["add", "--save-dev"]
  | Bun => ["add", "--dev"]
  | Deno => ["add", "--dev"]
  }
}
