module Bindings = FrontmanBindings
module Fs = Bindings.Fs

let fileExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    let stats = await Fs.Promises.stat(path)
    Fs.isFile(stats)
  } catch {
  | _ => false
  }
}

let findFirstExisting = async (candidates: array<string>): option<string> => {
  let rec checkNext = async (index: int): option<string> => {
    if index >= Array.length(candidates) {
      None
    } else {
      let candidate = Array.getUnsafe(candidates, index)
      let exists = await fileExists(candidate)

      if exists {
        Some(candidate)
      } else {
        await checkNext(index + 1)
      }
    }
  }

  await checkNext(0)
}

let findAllExisting = async (candidates: array<string>): array<string> => {
  let checks = candidates->Array.map(async candidate => {
    let exists = await fileExists(candidate)
    if exists {
      Some(candidate)
    } else {
      None
    }
  })

  let results = await Promise.all(checks)
  results->Array.filterMap(x => x)
}

let discoverLocalFiles = async (candidates: array<(string, array<string>)>): array<string> => {
  // For each directory, find the first existing file (if any)
  let searches = candidates->Array.map(async ((_dir, candidatePaths)) => {
    await findFirstExisting(candidatePaths)
  })

  let results = await Promise.all(searches)

  // Filter out None values and extract the paths
  results->Array.filterMap(x => x)
}

let discoverGlobalFiles = async (candidates: array<string>): array<string> => {
  let found = await findFirstExisting(candidates)

  switch found {
  | Some(path) => [path]
  | None => []
  }
}

let readFile = async (path: string): string => {
  try {
    await Fs.Promises.readFile(path)
  } catch {
  | _ => ""
  }
}

let loadFiles = async (paths: array<string>): array<(string, string)> => {
  let reads = paths->Array.map(async path => {
    let content = await readFile(path)
    (path, content)
  })

  await Promise.all(reads)
}
