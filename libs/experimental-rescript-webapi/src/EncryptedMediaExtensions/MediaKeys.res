@send
external createSession: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ~sessionType: EncryptedMediaExtensionsTypes.mediaKeySessionType=?,
) => EncryptedMediaExtensionsTypes.mediaKeySession = "createSession"

@send
external getStatusForPolicy: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ~policy: EncryptedMediaExtensionsTypes.mediaKeysPolicy=?,
) => promise<EncryptedMediaExtensionsTypes.mediaKeyStatus> = "getStatusForPolicy"

@send
external setServerCertificate: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  DataView.t,
) => promise<bool> = "setServerCertificate"

@send
external setServerCertificate2: (
  EncryptedMediaExtensionsTypes.mediaKeys,
  ArrayBuffer.t,
) => promise<bool> = "setServerCertificate"
