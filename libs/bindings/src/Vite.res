type libraryBuildConfig = {
  "configFile": bool,
  "build": {"lib": {"entry": string, "formats": array<string>}, "write": bool, "minify": bool},
  "define": Dict.t<string>,
}
type bundle = {output: array<{"type": string, "isEntry": option<bool>, "code": option<string>}>}
@module("vite")
external buildLibrary: libraryBuildConfig => Promise.t<array<bundle>> = "build"
