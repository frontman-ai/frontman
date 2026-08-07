@send
external get: (
  CredentialManagementTypes.credentialsContainer,
  ~options: CredentialManagementTypes.credentialRequestOptions=?,
) => promise<CredentialManagementTypes.credential> = "get"

@send
external store: (
  CredentialManagementTypes.credentialsContainer,
  CredentialManagementTypes.credential,
) => promise<unit> = "store"

@send
external create: (
  CredentialManagementTypes.credentialsContainer,
  ~options: CredentialManagementTypes.credentialCreationOptions=?,
) => promise<CredentialManagementTypes.credential> = "create"

@send
external preventSilentAccess: CredentialManagementTypes.credentialsContainer => promise<unit> =
  "preventSilentAccess"
