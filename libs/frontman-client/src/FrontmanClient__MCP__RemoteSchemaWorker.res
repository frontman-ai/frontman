module Engine = FrontmanClient__MCP__RemoteSchemaEngine

type request = {
  operation: string,
  schema: JSON.t,
  value: JSON.t,
  limits: Engine.limits,
}

type response = {ok: bool, error: option<string>, ready?: bool}
type messageEvent<'value> = {data: 'value}
type scope

@val external scope: scope = "self"
@set external setOnMessage: (scope, messageEvent<request> => unit) => unit = "onmessage"
@send external postMessage: (scope, response) => unit = "postMessage"

let respond = result =>
  switch result {
  | Ok(_) => scope->postMessage({ok: true, error: None, ready: false})
  | Error(error) => scope->postMessage({ok: false, error: Some(error), ready: false})
  }

scope->postMessage({ok: true, error: None, ready: true})

scope->setOnMessage(event => {
  let request = event.data
  switch request.operation {
  | "compile" => Engine.compileSchema(~schema=request.schema, ~limits=request.limits)->respond
  | "validate" => Engine.validateValue(~schema=request.schema, ~value=request.value)->respond
  | _ => JsError.throwWithMessage("Unknown remote schema worker operation")
  }
})
