type t = RemotePlaybackTypes.remotePlayback = private {...RemotePlaybackTypes.remotePlayback}
type remotePlaybackAvailabilityCallback = RemotePlaybackTypes.remotePlaybackAvailabilityCallback

include EventTarget.Impl({type t = t})

@send
external watchAvailability: (t, remotePlaybackAvailabilityCallback) => promise<int> =
  "watchAvailability"

@send
external cancelWatchAvailability: (t, ~id: int=?) => promise<unit> = "cancelWatchAvailability"

@send
external prompt: t => promise<unit> = "prompt"

module Types = RemotePlaybackTypes
