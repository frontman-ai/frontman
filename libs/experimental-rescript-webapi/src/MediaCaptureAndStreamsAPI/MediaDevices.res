open MediaCaptureAndStreamsAPI

include EventTarget.Impl({type t = mediaDevices})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/enumerateDevices)
*/
@send
external enumerateDevices: mediaDevices => promise<array<mediaDeviceInfo>> = "enumerateDevices"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getSupportedConstraints)
*/
@send
external getSupportedConstraints: mediaDevices => mediaTrackSupportedConstraints =
  "getSupportedConstraints"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getUserMedia)
*/
@send
external getUserMedia: (
  mediaDevices,
  ~constraints: mediaStreamConstraints=?,
) => promise<mediaStream> = "getUserMedia"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getDisplayMedia)
*/
@send
external getDisplayMedia: (
  mediaDevices,
  ~options: displayMediaStreamOptions=?,
) => promise<mediaStream> = "getDisplayMedia"
