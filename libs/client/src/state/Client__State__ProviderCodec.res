let encodeUserApiKeySaveRequest = (~provider, ~key) => {
  let payload: Client__State__Types.userApiKeySaveRequest = {provider, key}
  payload
  ->S.decodeOrThrow(
    ~from=Client__State__Types.userApiKeySaveRequestSchema,
    ~to=S.json->S.noValidation(true),
  )
  ->JSON.stringify
}

let customProviderCreateRequestSchema = S.object(s => (
  s.field("name", S.string),
  s.field("base_url", S.string),
  s.field("models", S.array(S.string)),
  s.field("api_key", S.option(S.string)),
))
let customProviderApiKeyChangeRequestSchema = S.object(s => (
  s.field("action", S.string),
  s.field("value", S.option(S.string)),
))
let customProviderUpdateRequestSchema = S.object(s => (
  s.field("name", S.string),
  s.field("base_url", S.string),
  s.field("models", S.array(S.string)),
  s.field("lock_version", S.int),
  s.field("api_key_change", customProviderApiKeyChangeRequestSchema),
))

let jsonString = (value, schema) =>
  value
  ->S.decodeOrThrow(~from=schema, ~to=S.json)
  ->JSON.stringifyAny
  ->Option.getOrThrow(~message="Expected schema output to be JSON")

let encodeCustomProviderSaveRequest = (draft: Client__State__Types.customProviderDraft) =>
  switch draft.id {
  | None =>
    let apiKey = switch draft.apiKeyChange {
    | ReplaceCustomProviderApiKey(value) => Some(value)
    | KeepCustomProviderApiKey | ClearCustomProviderApiKey => None
    }
    jsonString((draft.name, draft.baseUrl, draft.models, apiKey), customProviderCreateRequestSchema)
  | Some(_) =>
    let apiKeyChange = switch draft.apiKeyChange {
    | KeepCustomProviderApiKey => ("keep", None)
    | ClearCustomProviderApiKey => ("clear", None)
    | ReplaceCustomProviderApiKey(value) => ("replace", Some(value))
    }
    jsonString(
      (draft.name, draft.baseUrl, draft.models, draft.lockVersion->Option.getOrThrow, apiKeyChange),
      customProviderUpdateRequestSchema,
    )
  }

let customProviderValidationErrorsSchema = S.object(s =>
  s.field("errors", S.dict(S.array(S.string)))
)
let customProviderConflictSchema = S.object(s =>
  s.field("current_provider", Client__State__Types.customProviderSchema)
)

let decodeCustomProviderMutationError = (~status, ~json) =>
  switch status {
  | 404 => Client__State__Types.CustomProviderNotFound
  | 409 =>
    let provider = json->S.decodeOrThrow(~from=S.json, ~to=customProviderConflictSchema)
    Client__State__Types.CustomProviderConflict(provider)
  | 422 =>
    let errors = json->S.decodeOrThrow(~from=S.json, ~to=customProviderValidationErrorsSchema)
    Client__State__Types.CustomProviderValidationError(errors)
  | _ =>
    Client__State__Types.CustomProviderNetworkError(
      json->JSON.stringifyAny->Option.getOr(`HTTP ${status->Int.toString}`),
    )
  }

let customProviderSaveTarget = (~apiBaseUrl, draft: Client__State__Types.customProviderDraft) =>
  switch draft.id {
  | Some(providerId) => (`${apiBaseUrl}/api/user/custom-providers/${providerId}`, "PUT")
  | None => (`${apiBaseUrl}/api/user/custom-providers`, "POST")
  }

let customProviderDeleteUrl = (~apiBaseUrl, ~id, ~lockVersion) =>
  `${apiBaseUrl}/api/user/custom-providers/${id}?lock_version=${lockVersion->Int.toString}`
