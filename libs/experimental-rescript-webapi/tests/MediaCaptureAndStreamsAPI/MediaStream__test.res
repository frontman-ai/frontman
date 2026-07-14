let mediaStream: MediaCaptureAndStreamsTypes.mediaStream = Obj.magic()
let mediaStreamTrack: MediaCaptureAndStreamsTypes.mediaStreamTrack = Obj.magic()

let _make = MediaStream.make()

let _fromMediaStream = MediaStream.fromMediaStream(mediaStream)

let _fromTracks = MediaStream.fromTracks([mediaStreamTrack])
