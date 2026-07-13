type t = MediaCaptureAndStreamsTypes.mediaStream = private {
  ...MediaCaptureAndStreamsTypes.mediaStream,
}

/**
`make()`

Creates a new empty `MediaStream`.

```res
let stream = MediaStream.make()
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external make: unit => t = "MediaStream"

/**
`fromMediaStream(mediaStream)`

Creates a new `MediaStream` by copying another `MediaStream`.

```res
let copiedStream = MediaStream.fromMediaStream(existingStream)
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external fromMediaStream: t => t = "MediaStream"

/**
`fromTracks(array<MediaStreamTrack.t>)`

Creates a new `MediaStream` from an array of `MediaStreamTrack.t` values.

```res
let stream = MediaStream.fromTracks([audioTrack, videoTrack])
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external fromTracks: array<MediaStreamTrack.t> => t = "MediaStream"

include EventTarget.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getAudioTracks)
*/
@send
external getAudioTracks: t => array<MediaStreamTrack.t> = "getAudioTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getVideoTracks)
*/
@send
external getVideoTracks: t => array<MediaStreamTrack.t> = "getVideoTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getTracks)
*/
@send
external getTracks: t => array<MediaStreamTrack.t> = "getTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getTrackById)
*/
@send
external getTrackById: (t, string) => MediaStreamTrack.t = "getTrackById"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/addTrack)
*/
@send
external addTrack: (t, MediaStreamTrack.t) => unit = "addTrack"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/removeTrack)
*/
@send
external removeTrack: (t, MediaStreamTrack.t) => unit = "removeTrack"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/clone)
*/
@send
external clone: t => t = "clone"
