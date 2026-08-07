/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/encrypt)
*/
@send
external encrypt: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<ArrayBuffer.t> = "encrypt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/decrypt)
*/
@send
external decrypt: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<ArrayBuffer.t> = "decrypt"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/sign)
*/
@send
external sign: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "sign"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/verify)
*/
@send
external verify: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~signature: ArrayBufferTypedArrayOrDataView.t,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "verify"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/digest)
*/
@send
external digest: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "digest"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/generateKey)
*/
@send
external generateKey: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithm,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "generateKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/generateKey)
*/
@send
external generateKey2: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: string,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "generateKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/deriveKey)
*/
@send
external deriveKey: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~derivedKeyType: WebCryptoTypes.algorithmIdentifier,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "deriveKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/deriveBits)
*/
@send
external deriveBits: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithm,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~length: int=?,
) => promise<ArrayBuffer.t> = "deriveBits"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/deriveBits)
*/
@send
external deriveBits2: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: string,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~length: int=?,
) => promise<ArrayBuffer.t> = "deriveBits"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/importKey)
*/
@send
external importKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: unknown,
  ~keyData: ArrayBufferTypedArrayOrDataView.t,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<WebCryptoTypes.cryptoKey> = "importKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/exportKey)
*/
@send
external exportKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
) => promise<JSON.t> = "exportKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/wrapKey)
*/
@send
external wrapKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
  ~wrappingKey: WebCryptoTypes.cryptoKey,
  ~wrapAlgorithm: WebCryptoTypes.algorithm,
) => promise<JSON.t> = "wrapKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/wrapKey)
*/
@send
external wrapKey2: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
  ~wrappingKey: WebCryptoTypes.cryptoKey,
  ~wrapAlgorithm: string,
) => promise<JSON.t> = "wrapKey"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SubtleCrypto/unwrapKey)
*/
@send
external unwrapKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~wrappedKey: ArrayBufferTypedArrayOrDataView.t,
  ~unwrappingKey: WebCryptoTypes.cryptoKey,
  ~unwrapAlgorithm: WebCryptoTypes.algorithmIdentifier,
  ~unwrappedKeyAlgorithm: WebCryptoTypes.algorithmIdentifier,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<WebCryptoTypes.cryptoKey> = "unwrapKey"
