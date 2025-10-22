@@warning("-30")

open EventAPI

type remotePlaybackState =
  | @as("connected") Connected
  | @as("connecting") Connecting
  | @as("disconnected") Disconnected

/**
[See RemotePlayback on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback)
*/
@editor.completeFrom(RemotePlayback)
type remotePlayback = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/state)
    */
  state: remotePlaybackState,
}

type remotePlaybackAvailabilityCallback = bool => unit
