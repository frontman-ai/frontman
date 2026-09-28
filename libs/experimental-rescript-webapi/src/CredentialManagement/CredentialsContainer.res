/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/get)
*/
@send
external get: (
  CredentialManagementTypes.credentialsContainer,
  ~options: CredentialManagementTypes.credentialRequestOptions=?,
) => promise<CredentialManagementTypes.credential> = "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/store)
*/
@send
external store: (
  CredentialManagementTypes.credentialsContainer,
  CredentialManagementTypes.credential,
) => promise<unit> = "store"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/create)
*/
@send
external create: (
  CredentialManagementTypes.credentialsContainer,
  ~options: CredentialManagementTypes.credentialCreationOptions=?,
) => promise<CredentialManagementTypes.credential> = "create"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer/preventSilentAccess)
*/
@send
external preventSilentAccess: CredentialManagementTypes.credentialsContainer => promise<unit> =
  "preventSilentAccess"
