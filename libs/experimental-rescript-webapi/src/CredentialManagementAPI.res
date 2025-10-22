@@warning("-30")

open Prelude
open EventAPI

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

/**
[See CredentialsContainer on MDN](https://developer.mozilla.org/docs/Web/API/CredentialsContainer)
*/
@editor.completeFrom(CredentialsContainer)
type credentialsContainer = {}

/**
[See Credential on MDN](https://developer.mozilla.org/docs/Web/API/Credential)
*/
type credential = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Credential/id)
    */
  id: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Credential/type)
    */
  @as("type")
  type_: string,
}

type publicKeyCredentialDescriptor = {
  @as("type") mutable type_: publicKeyCredentialType,
  mutable id: bufferSource,
  mutable transports?: array<authenticatorTransport>,
}

type authenticationExtensionsPRFValues = {
  mutable first: bufferSource,
  mutable second?: bufferSource,
}

type authenticationExtensionsPRFInputs = {
  mutable eval?: authenticationExtensionsPRFValues,
  mutable evalByCredential?: any,
}

type authenticationExtensionsClientInputs = {
  mutable minPinLength?: bool,
  mutable hmacCreateSecret?: bool,
  mutable appid?: string,
  mutable credProps?: bool,
  mutable prf?: authenticationExtensionsPRFInputs,
}

type publicKeyCredentialRequestOptions = {
  mutable challenge: bufferSource,
  mutable timeout?: int,
  mutable rpId?: string,
  mutable allowCredentials?: array<publicKeyCredentialDescriptor>,
  mutable userVerification?: userVerificationRequirement,
  mutable extensions?: authenticationExtensionsClientInputs,
}

type credentialRequestOptions = {
  mutable mediation?: credentialMediationRequirement,
  mutable signal?: abortSignal,
  mutable publicKey?: publicKeyCredentialRequestOptions,
}

type publicKeyCredentialEntity = {mutable name: string}

type publicKeyCredentialRpEntity = {
  ...publicKeyCredentialEntity,
  mutable id?: string,
}

type publicKeyCredentialUserEntity = {
  ...publicKeyCredentialEntity,
  mutable id: bufferSource,
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
  mutable challenge: bufferSource,
  mutable pubKeyCredParams: array<publicKeyCredentialParameters>,
  mutable timeout?: int,
  mutable excludeCredentials?: array<publicKeyCredentialDescriptor>,
  mutable authenticatorSelection?: authenticatorSelectionCriteria,
  mutable attestation?: attestationConveyancePreference,
  mutable extensions?: authenticationExtensionsClientInputs,
}

type credentialCreationOptions = {
  mutable signal?: abortSignal,
  mutable publicKey?: publicKeyCredentialCreationOptions,
}
