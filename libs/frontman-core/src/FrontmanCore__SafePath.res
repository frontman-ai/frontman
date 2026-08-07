module Path = FrontmanBindings.Path

type t = {path: string}

let endsWithSep = (path: string): bool => {
  path->String.endsWith("/") || path->String.endsWith("\\")
}

let resolve = (~sourceRoot: string, ~inputPath: string): result<t, string> => {
  let normalizedRoot = Path.resolve(sourceRoot)
  let rootWithSep = if endsWithSep(normalizedRoot) {
    normalizedRoot
  } else {
    normalizedRoot ++ Path.sep
  }

  if Path.isAbsolute(inputPath) {
    let normalizedPath = Path.normalize(inputPath)

    if normalizedPath == normalizedRoot || normalizedPath->String.startsWith(rootWithSep) {
      Ok({path: normalizedPath})
    } else {
      Error(`Absolute path must be under source root: ${inputPath}`)
    }
  } else {
    let fullPath = Path.normalize(Path.join([normalizedRoot, inputPath]))

    if fullPath == normalizedRoot || fullPath->String.startsWith(rootWithSep) {
      Ok({path: fullPath})
    } else {
      Error(`Path escapes source root: ${inputPath}`)
    }
  }
}

let toString = (safePath: t): string => safePath.path

let dirname = (safePath: t): string => Path.dirname(safePath.path)

let join = (~sourceRoot: string, safePath: t, segments: array<string>): result<t, string> => {
  let newPath = Path.join(Array.concat([safePath.path], segments))
  resolve(~sourceRoot, ~inputPath=newPath)
}
