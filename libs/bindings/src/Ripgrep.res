@module("./RipgrepRuntime.mjs")
external getRipgrepPathRaw: unit => promise<Nullable.t<string>> = "getRipgrepPath"

let getRipgrepPath = async (): option<string> => {
  (await getRipgrepPathRaw())->Nullable.toOption
}
