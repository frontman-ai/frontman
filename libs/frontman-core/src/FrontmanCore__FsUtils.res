// Shared async filesystem existence checks.
//
// Centralises the try-access-catch pattern that was duplicated across tools
// and CLI detect modules. Three flavours cover every use-case:
//
//   pathExists  – does *something* exist at this path? (file, dir, symlink …)
//   fileExists  – exists AND is a regular file
//   dirExists   – exists AND is a directory

module Fs = FrontmanBindings.Fs

let pathExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    true
  } catch {
  | _ => false
  }
}

let fileExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    let stats = await Fs.Promises.stat(path)
    Fs.isFile(stats)
  } catch {
  | _ => false
  }
}

let dirExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    let stats = await Fs.Promises.stat(path)
    Fs.isDirectory(stats)
  } catch {
  | _ => false
  }
}
