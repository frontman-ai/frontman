module NodePath = FrontmanBindings.Path
module PathStringUtils = FrontmanCore__PathStringUtils

type t =
  | AbsolutePath(string)
  | RelativePath(string)

let normalizeInputSeparators = (path: string): string => path->PathStringUtils.toForwardSlashes

let fromString = (path: string): t => {
  let normalized = normalizeInputSeparators(path)
  switch NodePath.isAbsolute(normalized) {
  | true => AbsolutePath(normalized)
  | false => RelativePath(normalized)
  }
}

let absolute = (path: string): t => AbsolutePath(path->normalizeInputSeparators)

let relative = (path: string): t => RelativePath(path->normalizeInputSeparators)

let toString = (path: t): string => {
  switch path {
  | AbsolutePath(path) | RelativePath(path) => path
  }
}

let fold = (path: t, ~absolute: string => 'a, ~relative: string => 'a): 'a => {
  switch path {
  | AbsolutePath(path) => absolute(path)
  | RelativePath(path) => relative(path)
  }
}
