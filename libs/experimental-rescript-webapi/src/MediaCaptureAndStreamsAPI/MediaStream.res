open MediaCaptureAndStreamsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external make: unit => mediaStream = "MediaStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external make2: mediaStream => mediaStream = "MediaStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream)
*/
@new
external make3: array<mediaStreamTrack> => mediaStream = "MediaStream"

include EventTarget.Impl({type t = mediaStream})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getAudioTracks)
*/
@send
external getAudioTracks: mediaStream => array<mediaStreamTrack> = "getAudioTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getVideoTracks)
*/
@send
external getVideoTracks: mediaStream => array<mediaStreamTrack> = "getVideoTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getTracks)
*/
@send
external getTracks: mediaStream => array<mediaStreamTrack> = "getTracks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/getTrackById)
*/
@send
external getTrackById: (mediaStream, string) => mediaStreamTrack = "getTrackById"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/addTrack)
*/
@send
external addTrack: (mediaStream, mediaStreamTrack) => unit = "addTrack"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/removeTrack)
*/
@send
external removeTrack: (mediaStream, mediaStreamTrack) => unit = "removeTrack"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStream/clone)
*/
@send
external clone: mediaStream => mediaStream = "clone"
