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

@send
external enumerateDevices: t => promise<array<MediaDeviceInfo.t>> = "enumerateDevices"

@send
external getSupportedConstraints: t => mediaTrackSupportedConstraints = "getSupportedConstraints"

@send
external getUserMedia: (t, ~constraints: mediaStreamConstraints=?) => promise<MediaStream.t> =
  "getUserMedia"

@send
external getDisplayMedia: (t, ~options: displayMediaStreamOptions=?) => promise<MediaStream.t> =
  "getDisplayMedia"
