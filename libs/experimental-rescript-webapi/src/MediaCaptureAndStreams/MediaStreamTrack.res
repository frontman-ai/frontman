type t = MediaCaptureAndStreamsTypes.mediaStreamTrack = private {
  ...MediaCaptureAndStreamsTypes.mediaStreamTrack,
}
type mediaTrackCapabilities = MediaCaptureAndStreamsTypes.mediaTrackCapabilities = {
  ...MediaCaptureAndStreamsTypes.mediaTrackCapabilities,
}
type mediaTrackConstraints = MediaCaptureAndStreamsTypes.mediaTrackConstraints = {
  ...MediaCaptureAndStreamsTypes.mediaTrackConstraints,
}
type mediaTrackSettings = MediaCaptureAndStreamsTypes.mediaTrackSettings = {
  ...MediaCaptureAndStreamsTypes.mediaTrackSettings,
}

include EventTarget.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/clone)
*/
@send
external clone: t => t = "clone"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/stop)
*/
@send
external stop: t => unit = "stop"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getCapabilities)
*/
@send
external getCapabilities: t => mediaTrackCapabilities = "getCapabilities"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getConstraints)
*/
@send
external getConstraints: t => mediaTrackConstraints = "getConstraints"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getSettings)
*/
@send
external getSettings: t => mediaTrackSettings = "getSettings"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/applyConstraints)
*/
@send
external applyConstraints: (t, ~constraints: mediaTrackConstraints=?) => promise<unit> =
  "applyConstraints"
