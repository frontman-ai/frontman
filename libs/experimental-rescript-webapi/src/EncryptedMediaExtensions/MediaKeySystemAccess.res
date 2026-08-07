/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySystemAccess/getConfiguration)
*/
@send
external getConfiguration: EncryptedMediaExtensionsTypes.mediaKeySystemAccess => EncryptedMediaExtensionsTypes.mediaKeySystemConfiguration =
  "getConfiguration"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySystemAccess/createMediaKeys)
*/
@send
external createMediaKeys: EncryptedMediaExtensionsTypes.mediaKeySystemAccess => promise<
  EncryptedMediaExtensionsTypes.mediaKeys,
> = "createMediaKeys"
