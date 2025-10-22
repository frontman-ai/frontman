@@warning("-30")

open Prelude

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

/**
This Web Crypto API interface provides a number of low-level cryptographic functions. It is accessed via the Crypto.subtle properties available in a window context (via Window.crypto).
[See SubtleCrypto on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto)
*/
@editor.completeFrom(SubtleCrypto)
type subtleCrypto = {}

/**
Basic cryptography features available in the current context. It allows access to a cryptographically strong random number generator and to cryptographic primitives.
[See Crypto on MDN](https://developer.mozilla.org/docs/Web/API/Crypto)
*/
@editor.completeFrom(Crypto)
type crypto = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Crypto/subtle)
    */
  subtle: subtleCrypto,
}

/**
The CryptoKey dictionary of the Web Crypto API represents a cryptographic key.
[See CryptoKey on MDN](https://developer.mozilla.org/docs/Web/API/CryptoKey)
*/
type cryptoKey = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CryptoKey/type)
    */
  @as("type")
  type_: keyType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CryptoKey/extractable)
    */
  extractable: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CryptoKey/algorithm)
    */
  algorithm: keyAlgorithm,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CryptoKey/usages)
    */
  usages: array<keyUsage>,
}

type algorithmIdentifier = any

type algorithm = {mutable name: string}
