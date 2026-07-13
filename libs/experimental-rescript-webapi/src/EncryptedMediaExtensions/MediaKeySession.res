include EventTarget.Impl({type t = EncryptedMediaExtensionsTypes.mediaKeySession})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/generateRequest)
*/
@send
external generateRequest: (
  EncryptedMediaExtensionsTypes.mediaKeySession,
  ~initDataType: string,
  ~initData: DataView.t,
) => promise<unit> = "generateRequest"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/generateRequest)
*/
@send
external generateRequest2: (
  EncryptedMediaExtensionsTypes.mediaKeySession,
  ~initDataType: string,
  ~initData: ArrayBuffer.t,
) => promise<unit> = "generateRequest"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/load)
*/
@send
external load: (EncryptedMediaExtensionsTypes.mediaKeySession, string) => promise<bool> = "load"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/update)
*/
@send
external update: (EncryptedMediaExtensionsTypes.mediaKeySession, DataView.t) => promise<unit> =
  "update"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/update)
*/
@send
external update2: (EncryptedMediaExtensionsTypes.mediaKeySession, ArrayBuffer.t) => promise<unit> =
  "update"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/close)
*/
@send
external close: EncryptedMediaExtensionsTypes.mediaKeySession => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaKeySession/remove)
*/
@send
external remove: EncryptedMediaExtensionsTypes.mediaKeySession => promise<unit> = "remove"
