@@warning("-30")

type authenticatorTransport =
  | @as("ble") Ble
  | @as("hybrid") Hybrid
  | @as("internal") Internal
  | @as("nfc") Nfc
  | @as("usb") Usb

type credentialMediationRequirement =
  | @as("conditional") Conditional
  | @as("optional") Optional
  | @as("required") Required
  | @as("silent") Silent

type publicKeyCredentialType = | @as("public-key") PublicKey

type userVerificationRequirement =
  | @as("discouraged") Discouraged
  | @as("preferred") Preferred
  | @as("required") Required

type authenticatorAttachment =
  | @as("cross-platform") CrossPlatform
  | @as("platform") Platform

type residentKeyRequirement =
  | @as("discouraged") Discouraged
  | @as("preferred") Preferred
  | @as("required") Required

type attestationConveyancePreference =
  | @as("direct") Direct
  | @as("enterprise") Enterprise
  | @as("indirect") Indirect
  | @as("none") None

@editor.completeFrom(CredentialsContainer)
type credentialsContainer = private {}

type credential = {
  id: string,
  @as("type")
  type_: string,
}

type publicKeyCredentialDescriptor = {
  @as("type") mutable type_: publicKeyCredentialType,
  mutable id: ArrayBufferTypedArrayOrDataView.t,
  mutable transports?: array<authenticatorTransport>,
}

type authenticationExtensionsPRFValues = {
  mutable first: ArrayBufferTypedArrayOrDataView.t,
  mutable second?: ArrayBufferTypedArrayOrDataView.t,
}

type authenticationExtensionsPRFInputs = {
  mutable eval?: authenticationExtensionsPRFValues,
  mutable evalByCredential?: unknown,
}

type authenticationExtensionsClientInputs = {
  mutable minPinLength?: bool,
  mutable hmacCreateSecret?: bool,
  mutable appid?: string,
  mutable credProps?: bool,
  mutable prf?: authenticationExtensionsPRFInputs,
}

type publicKeyCredentialRequestOptions = {
  mutable challenge: ArrayBufferTypedArrayOrDataView.t,
  mutable timeout?: int,
  mutable rpId?: string,
  mutable allowCredentials?: array<publicKeyCredentialDescriptor>,
  mutable userVerification?: userVerificationRequirement,
  mutable extensions?: authenticationExtensionsClientInputs,
}

type credentialRequestOptions = {
  mutable mediation?: credentialMediationRequirement,
  mutable signal?: EventTypes.abortSignal,
  mutable publicKey?: publicKeyCredentialRequestOptions,
}

type publicKeyCredentialEntity = {mutable name: string}

type publicKeyCredentialRpEntity = {
  ...publicKeyCredentialEntity,
  mutable id?: string,
}

type publicKeyCredentialUserEntity = {
  ...publicKeyCredentialEntity,
  mutable id: ArrayBufferTypedArrayOrDataView.t,
  mutable displayName: string,
}

type publicKeyCredentialParameters = {
  @as("type") mutable type_: publicKeyCredentialType,
  mutable alg: int,
}

type authenticatorSelectionCriteria = {
  mutable authenticatorAttachment?: authenticatorAttachment,
  mutable residentKey?: residentKeyRequirement,
  mutable requireResidentKey?: bool,
  mutable userVerification?: userVerificationRequirement,
}

type publicKeyCredentialCreationOptions = {
  mutable rp: publicKeyCredentialRpEntity,
  mutable user: publicKeyCredentialUserEntity,
  mutable challenge: ArrayBufferTypedArrayOrDataView.t,
  mutable pubKeyCredParams: array<publicKeyCredentialParameters>,
  mutable timeout?: int,
  mutable excludeCredentials?: array<publicKeyCredentialDescriptor>,
  mutable authenticatorSelection?: authenticatorSelectionCriteria,
  mutable attestation?: attestationConveyancePreference,
  mutable extensions?: authenticationExtensionsClientInputs,
}

type credentialCreationOptions = {
  mutable signal?: EventTypes.abortSignal,
  mutable publicKey?: publicKeyCredentialCreationOptions,
}
