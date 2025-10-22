open CredentialManagementAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/get)
*/
@send
external get: (credentialsContainer, ~options: credentialRequestOptions=?) => promise<credential> =
  "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/store)
*/
@send
external store: (credentialsContainer, credential) => promise<unit> = "store"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/create)
*/
@send
external create: (
  credentialsContainer,
  ~options: credentialCreationOptions=?,
) => promise<credential> = "create"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/preventSilentAccess)
*/
@send
external preventSilentAccess: credentialsContainer => promise<unit> = "preventSilentAccess"
