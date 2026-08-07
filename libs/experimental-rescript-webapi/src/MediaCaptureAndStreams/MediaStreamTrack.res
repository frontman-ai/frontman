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

@send
external clone: t => t = "clone"

@send
external stop: t => unit = "stop"

@send
external getCapabilities: t => mediaTrackCapabilities = "getCapabilities"

@send
external getConstraints: t => mediaTrackConstraints = "getConstraints"

@send
external getSettings: t => mediaTrackSettings = "getSettings"

@send
external applyConstraints: (t, ~constraints: mediaTrackConstraints=?) => promise<unit> =
  "applyConstraints"
