module Fs = FrontmanBindings.Fs

let readFileIfExists = async (path: string): option<string> => {
  try {
    Some(await Fs.Promises.readFile(path))
  } catch {
  | exn =>
    switch exn
    ->JsExn.fromException
    ->Option.flatMap(error => error->Fs.errorCode->Nullable.toOption) {
    | Some("ENOENT") => None
    | Some(_) | None => throw(exn)
    }
  }
}

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
