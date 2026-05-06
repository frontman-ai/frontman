module Path = FrontmanBindings.Path
module FsUtils = FrontmanCore__FsUtils

type t =
  | Npm
  | Yarn
  | Pnpm
  | Bun
  | Deno

let checkDir = async (dir: string): option<t> => {
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

let detect = async (projectDir: string): t => {
  switch await checkDir(projectDir) {
  | Some(pm) => pm
  | None =>
    let parentDir = Path.dirname(projectDir)
    if parentDir != projectDir {
      switch await checkDir(parentDir) {
      | Some(pm) => pm
      | None =>
        let grandparentDir = Path.dirname(parentDir)
        if grandparentDir != parentDir {
          switch await checkDir(grandparentDir) {
          | Some(pm) => pm
          | None => Npm
          }
        } else {
          Npm
        }
      }
    } else {
      Npm
    }
  }
}

let command = (pm: t): string => {
  switch pm {
  | Npm => "npm"
  | Yarn => "npx yarn"
  | Pnpm => "npx pnpm"
  | Bun => "bun"
  | Deno => "deno"
  }
}

let devCommand = (pm: t): string => {
  switch pm {
  | Npm => "npm run dev"
  | Yarn => "yarn dev"
  | Pnpm => "pnpm dev"
  | Bun => "bun dev"
  | Deno => "deno task dev"
  }
}

let devInstallArgs = (pm: t): array<string> => {
  switch pm {
  | Npm => ["install", "-D"]
  | Yarn => ["add", "-D"]
  | Pnpm => ["add", "--save-dev"]
  | Bun => ["add", "--dev"]
  | Deno => ["add", "--dev"]
  }
}

let npmPackages = (pm: t, packages: array<string>): array<string> => {
  switch pm {
  | Deno => packages->Array.map(packageName => "npm:" ++ packageName)
  | Npm | Yarn | Pnpm | Bun => packages
  }
}
