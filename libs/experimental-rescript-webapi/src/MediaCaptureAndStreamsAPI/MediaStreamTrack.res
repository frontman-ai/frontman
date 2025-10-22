open MediaCaptureAndStreamsAPI

include EventTarget.Impl({type t = mediaStreamTrack})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/clone)
*/
@send
external clone: mediaStreamTrack => mediaStreamTrack = "clone"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/stop)
*/
@send
external stop: mediaStreamTrack => unit = "stop"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getCapabilities)
*/
@send
external getCapabilities: mediaStreamTrack => mediaTrackCapabilities = "getCapabilities"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getConstraints)
*/
@send
external getConstraints: mediaStreamTrack => mediaTrackConstraints = "getConstraints"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/getSettings)
*/
@send
external getSettings: mediaStreamTrack => mediaTrackSettings = "getSettings"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamTrack/applyConstraints)
*/
@send
external applyConstraints: (
  mediaStreamTrack,
  ~constraints: mediaTrackConstraints=?,
) => promise<unit> = "applyConstraints"
