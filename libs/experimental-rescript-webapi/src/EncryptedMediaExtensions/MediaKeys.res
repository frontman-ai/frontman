/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeys/createSession)
*/
@send
external createSession: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ~sessionType: EncryptedMediaExtensionsTypes.mediaKeySessionType=?,
) => EncryptedMediaExtensionsTypes.mediaKeySession = "createSession"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeys/getStatusForPolicy)
*/
@send
external getStatusForPolicy: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ~policy: EncryptedMediaExtensionsTypes.mediaKeysPolicy=?,
) => promise<EncryptedMediaExtensionsTypes.mediaKeyStatus> = "getStatusForPolicy"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeys/setServerCertificate)
*/
@send
external setServerCertificate: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  DataView.t,
) => promise<bool> = "setServerCertificate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeys/setServerCertificate)
*/
@send
external setServerCertificate2: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ArrayBuffer.t,
) => promise<bool> = "setServerCertificate"
