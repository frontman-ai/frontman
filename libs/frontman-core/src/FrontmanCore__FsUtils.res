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
