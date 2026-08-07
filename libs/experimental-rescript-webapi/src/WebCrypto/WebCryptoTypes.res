@@warning("-30")

type keyType =
  | @as("private") Private
  | @as("public") Public
  | @as("secret") Secret

type keyUsage =
  | @as("decrypt") Decrypt
  | @as("deriveBits") DeriveBits
  | @as("deriveKey") DeriveKey
  | @as("encrypt") Encrypt
  | @as("sign") Sign
  | @as("unwrapKey") UnwrapKey
  | @as("verify") Verify
  | @as("wrapKey") WrapKey

type keyFormat =
  | @as("jwk") Jwk
  | @as("pkcs8") Pkcs8
  | @as("raw") Raw
  | @as("spki") Spki

type keyAlgorithm = {mutable name: string}

@editor.completeFrom(SubtleCrypto)
type subtleCrypto = private {}

@editor.completeFrom(Crypto)
type crypto = private {
  subtle: subtleCrypto,
}

type cryptoKey = {
  @as("type")
  type_: keyType,
  extractable: bool,
  algorithm: keyAlgorithm,
  usages: array<keyUsage>,
}

type algorithmIdentifier = unknown

type algorithm = {mutable name: string}
