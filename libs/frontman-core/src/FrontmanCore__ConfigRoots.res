module NodePath = FrontmanBindings.Path
module Path = FrontmanCore__Path

let normalizeProjectRoot = (projectRoot: string): string =>
  projectRoot->NodePath.resolve->NodePath.normalize

let normalizeSourceRootPath = (~projectRoot: string, sourceRoot: Path.t): string =>
  sourceRoot->Path.fold(
    ~absolute=path => NodePath.normalize(path),
    ~relative=path => NodePath.resolveMany([projectRoot, path])->NodePath.normalize,
  )

let normalizeSourceRoot = (~projectRoot: string) =>
  (sourceRoot: string): string => normalizeSourceRootPath(~projectRoot, Path.fromString(sourceRoot))

let sourceRootOrProjectRoot = (~projectRoot: string, sourceRoot: option<string>): string => {
  sourceRoot->Option.map(normalizeSourceRoot(~projectRoot))->Option.getOr(projectRoot)
}

let sourceRootPathOrProjectRoot = (~projectRoot: string, sourceRoot: option<Path.t>): string => {
  sourceRoot
  ->Option.map(sourceRoot => normalizeSourceRootPath(~projectRoot, sourceRoot))
  ->Option.getOr(projectRoot)
}
