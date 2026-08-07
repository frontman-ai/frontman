@send
external getConfiguration: EncryptedMediaExtensionsTypes.mediaKeySystemAccess => EncryptedMediaExtensionsTypes.mediaKeySystemConfiguration =
  "getConfiguration"

@send
external createMediaKeys: EncryptedMediaExtensionsTypes.mediaKeySystemAccess => promise<
  EncryptedMediaExtensionsTypes.mediaKeys,
> = "createMediaKeys"
