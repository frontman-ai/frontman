type t = RemotePlaybackTypes.remotePlayback = private {...RemotePlaybackTypes.remotePlayback}
type remotePlaybackAvailabilityCallback = RemotePlaybackTypes.remotePlaybackAvailabilityCallback

include EventTarget.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/watchAvailability)
*/
@send
external watchAvailability: (t, remotePlaybackAvailabilityCallback) => promise<int> =
  "watchAvailability"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/cancelWatchAvailability)
*/
@send
external cancelWatchAvailability: (t, ~id: int=?) => promise<unit> = "cancelWatchAvailability"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/prompt)
*/
@send
external prompt: t => promise<unit> = "prompt"

module Types = RemotePlaybackTypes
