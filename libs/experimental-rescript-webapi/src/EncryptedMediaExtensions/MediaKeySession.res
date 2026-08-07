include EventTarget.Impl({type t = EncryptedMediaExtensionsTypes.mediaKeySession})

@send
external generateRequest: (
  EncryptedMediaExtensionsTypes.mediaKeySession,
  ~initDataType: string,
  ~initData: DataView.t,
) => promise<unit> = "generateRequest"

@send
external generateRequest2: (
  EncryptedMediaExtensionsTypes.mediaKeySession,
  ~initDataType: string,
  ~initData: ArrayBuffer.t,
) => promise<unit> = "generateRequest"

@send
external load: (EncryptedMediaExtensionsTypes.mediaKeySession, string) => promise<bool> = "load"

@send
external update: (EncryptedMediaExtensionsTypes.mediaKeySession, DataView.t) => promise<unit> =
  "update"

@send
external update2: (EncryptedMediaExtensionsTypes.mediaKeySession, ArrayBuffer.t) => promise<unit> =
  "update"

@send
external close: EncryptedMediaExtensionsTypes.mediaKeySession => promise<unit> = "close"

@send
external remove: EncryptedMediaExtensionsTypes.mediaKeySession => promise<unit> = "remove"
