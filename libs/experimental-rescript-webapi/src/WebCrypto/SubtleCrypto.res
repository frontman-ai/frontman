@send
external encrypt: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<ArrayBuffer.t> = "encrypt"

@send
external decrypt: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<ArrayBuffer.t> = "decrypt"

@send
external sign: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "sign"

@send
external verify: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~key: WebCryptoTypes.cryptoKey,
  ~signature: ArrayBufferTypedArrayOrDataView.t,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "verify"

@send
external digest: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~data: ArrayBufferTypedArrayOrDataView.t,
) => promise<JSON.t> = "digest"

@send
external generateKey: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithm,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "generateKey"

@send
external generateKey2: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: string,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "generateKey"

@send
external deriveKey: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~derivedKeyType: WebCryptoTypes.algorithmIdentifier,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<JSON.t> = "deriveKey"

@send
external deriveBits: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: WebCryptoTypes.algorithm,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~length: int=?,
) => promise<ArrayBuffer.t> = "deriveBits"

@send
external deriveBits2: (
  WebCryptoTypes.subtleCrypto,
  ~algorithm: string,
  ~baseKey: WebCryptoTypes.cryptoKey,
  ~length: int=?,
) => promise<ArrayBuffer.t> = "deriveBits"

@send
external importKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: unknown,
  ~keyData: ArrayBufferTypedArrayOrDataView.t,
  ~algorithm: WebCryptoTypes.algorithmIdentifier,
  ~extractable: bool,
  ~keyUsages: array<WebCryptoTypes.keyUsage>,
) => promise<WebCryptoTypes.cryptoKey> = "importKey"

@send
external exportKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
) => promise<JSON.t> = "exportKey"

@send
external wrapKey: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
  ~wrappingKey: WebCryptoTypes.cryptoKey,
  ~wrapAlgorithm: WebCryptoTypes.algorithm,
) => promise<JSON.t> = "wrapKey"

@send
external wrapKey2: (
  WebCryptoTypes.subtleCrypto,
  ~format: WebCryptoTypes.keyFormat,
  ~key: WebCryptoTypes.cryptoKey,
  ~wrappingKey: WebCryptoTypes.cryptoKey,
  ~wrapAlgorithm: string,
) => promise<JSON.t> = "wrapKey"

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
