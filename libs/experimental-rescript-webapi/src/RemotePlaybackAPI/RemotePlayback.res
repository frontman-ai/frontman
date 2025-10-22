open RemotePlaybackAPI

include EventTarget.Impl({type t = remotePlayback})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/watchAvailability)
*/
@send
external watchAvailability: (remotePlayback, remotePlaybackAvailabilityCallback) => promise<int> =
  "watchAvailability"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/cancelWatchAvailability)
*/
@send
external cancelWatchAvailability: (remotePlayback, ~id: int=?) => promise<unit> =
  "cancelWatchAvailability"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/prompt)
*/
@send
external prompt: remotePlayback => promise<unit> = "prompt"
