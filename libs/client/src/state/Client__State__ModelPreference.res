module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})

let selectedModelStorageKey = "frontman:selectedModelValue"

let migrateOpenAIModelValue = value =>
  switch value->String.startsWith("openai:") {
  | true => "openai_codex:" ++ value->String.slice(~start=7, ~end=String.length(value))
  | false => value
  }

let loadSelectedModelValueFromStorage = (): option<string> => {
  try {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.getItem(selectedModelStorageKey)
    ->Null.toOption
    ->Option.map(migrateOpenAIModelValue)
  } catch {
  | _ => None
  }
}

let syncSelectedModelValueToStorage = (value: option<string>): unit => {
  try {
    let storage = WebAPI.Window.current->WebAPI.Window.localStorage
    switch value {
    | Some(value) => storage->WebAPI.Storage.setItem(~key=selectedModelStorageKey, ~value)
    | None => storage->WebAPI.Storage.removeItem(selectedModelStorageKey)
    }
  } catch {
  | exn => Log.error(~error=JsExn.fromException(exn), "syncSelectedModelValueToStorage failed")
  }
}
