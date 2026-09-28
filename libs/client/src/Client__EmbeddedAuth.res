module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})

let tokenStorageKey = "frontman:embeddedClientToken"

let loadToken = (): option<string> => {
  try {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.getItem(tokenStorageKey)
    ->Null.toOption
  } catch {
  | exn =>
    Log.error(~error=JsExn.fromException(exn), "loadToken failed")
    None
  }
}

let saveToken = token => {
  try {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.setItem(~key=tokenStorageKey, ~value=token)
  } catch {
  | exn => Log.error(~error=JsExn.fromException(exn), "saveToken failed")
  }
}

let clearToken = () => {
  try {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.removeItem(tokenStorageKey)
  } catch {
  | exn => Log.error(~error=JsExn.fromException(exn), "clearToken failed")
  }
}

let authorizationHeaderValue = token => `Bearer ${token}`

let headers = (~contentType: option<string>=?) => {
  switch loadToken() {
  | Some(token) =>
    let headerValues = Dict.make()
    headerValues->Dict.set("Authorization", authorizationHeaderValue(token))
    contentType->Option.forEach(value => headerValues->Dict.set("Content-Type", value))
    Some(WebAPI.HeadersInit.fromDict(headerValues))
  | None => None
  }
}

let jsonHeaders = () => headers(~contentType="application/json")

let clearTokenOnUnauthorized = response => {
  switch response.WebAPI.Response.status {
  | 401 => clearToken()
  | _ => ()
  }
}
