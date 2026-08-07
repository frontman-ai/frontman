@get
external mediaKeys: DomTypes.htmlMediaElement => Null.t<EncryptedMediaExtensionsTypes.mediaKeys> =
  "mediaKeys"

@send
external setMediaKeys: (
  DomTypes.htmlMediaElement,
  EncryptedMediaExtensionsTypes.mediaKeys,
) => promise<unit> = "setMediaKeys"
