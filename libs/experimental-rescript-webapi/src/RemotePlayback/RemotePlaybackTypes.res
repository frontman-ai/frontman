@@warning("-30")

type remotePlaybackState =
  | @as("connected") Connected
  | @as("connecting") Connecting
  | @as("disconnected") Disconnected

/**
[See WebApiRemotePlayback on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback)
*/
@editor.completeFrom(WebApiRemotePlayback)
type remotePlayback = private {
  ...EventTypes.eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/RemotePlayback/state)
    */
  state: remotePlaybackState,
}

type remotePlaybackAvailabilityCallback = bool => unit
