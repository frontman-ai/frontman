type t = MediaCaptureAndStreamsTypes.mediaDevices = private {
  ...MediaCaptureAndStreamsTypes.mediaDevices,
}
type mediaTrackSupportedConstraints = MediaCaptureAndStreamsTypes.mediaTrackSupportedConstraints = {
  ...MediaCaptureAndStreamsTypes.mediaTrackSupportedConstraints,
}
type mediaStreamConstraints = MediaCaptureAndStreamsTypes.mediaStreamConstraints = {
  ...MediaCaptureAndStreamsTypes.mediaStreamConstraints,
}
type displayMediaStreamOptions = MediaCaptureAndStreamsTypes.displayMediaStreamOptions = {
  ...MediaCaptureAndStreamsTypes.displayMediaStreamOptions,
}

include EventTarget.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/enumerateDevices)
*/
@send
external enumerateDevices: t => promise<array<MediaDeviceInfo.t>> = "enumerateDevices"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getSupportedConstraints)
*/
@send
external getSupportedConstraints: t => mediaTrackSupportedConstraints = "getSupportedConstraints"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getUserMedia)
*/
@send
external getUserMedia: (t, ~constraints: mediaStreamConstraints=?) => promise<MediaStream.t> =
  "getUserMedia"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDevices/getDisplayMedia)
*/
@send
external getDisplayMedia: (t, ~options: displayMediaStreamOptions=?) => promise<MediaStream.t> =
  "getDisplayMedia"
