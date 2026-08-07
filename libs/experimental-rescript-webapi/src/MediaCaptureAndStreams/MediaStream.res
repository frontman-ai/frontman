type t = MediaCaptureAndStreamsTypes.mediaStream = private {
  ...MediaCaptureAndStreamsTypes.mediaStream,
}

@new
external make: unit => t = "MediaStream"

@new
external fromMediaStream: t => t = "MediaStream"

@new
external fromTracks: array<MediaStreamTrack.t> => t = "MediaStream"

include EventTarget.Impl({type t = t})

@send
external getAudioTracks: t => array<MediaStreamTrack.t> = "getAudioTracks"

@send
external getVideoTracks: t => array<MediaStreamTrack.t> = "getVideoTracks"

@send
external getTracks: t => array<MediaStreamTrack.t> = "getTracks"

@send
external getTrackById: (t, string) => MediaStreamTrack.t = "getTrackById"

@send
external addTrack: (t, MediaStreamTrack.t) => unit = "addTrack"

@send
external removeTrack: (t, MediaStreamTrack.t) => unit = "removeTrack"

@send
external clone: t => t = "clone"
