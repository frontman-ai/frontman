// Dotenv bindings for loading environment variables from .env files

type configOptions = {
  path: option<string>,
  encoding: option<string>,
  debug: option<bool>,
}

type configResult = {
  parsed: option<Dict.t<string>>,
  error: option<JsExn.t>,
}

// Main config function with options
@module("dotenv")
external configWithOptions: configOptions => configResult = "config"

// Simple config function (uses defaults)
let config = (~path: option<string>=?, ~debug: bool=false, ()): configResult => {
  configWithOptions({
    path,
    encoding: None,
    debug: Some(debug),
  })
}

// Process.env access
@scope("process") @val external env: Dict.t<string> = "env"

// Helper to get env var with optional default
let get = (~key: string, ~default: option<string>=?, ()): option<string> => {
  switch env->Dict.get(key) {
  | Some(value) => Some(value)
  | None => default
  }
}

// Helper to get required env var (throws if missing)
let getOrThrow = (key: string): string => {
  switch env->Dict.get(key) {
  | Some(value) => value
  | None => JsError.throwWithMessage(`Missing required environment variable: ${key}`)
  }
}
