@@warning("-30")

type remotePlaybackState =
  | @as("connected") Connected
  | @as("connecting") Connecting
  | @as("disconnected") Disconnected

@editor.completeFrom(WebApiRemotePlayback)
type remotePlayback = private {
  ...EventTypes.eventTarget,
  state: remotePlaybackState,
}

type remotePlaybackAvailabilityCallback = bool => unit
