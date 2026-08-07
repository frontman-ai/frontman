type t = MediaCaptureAndStreamsTypes.mediaDeviceInfo = private {
  ...MediaCaptureAndStreamsTypes.mediaDeviceInfo,
}

@send
external toJSON: t => Dict.t<string> = "toJSON"
