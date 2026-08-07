type t = MediaSessionTypes.mediaSession = private {...MediaSessionTypes.mediaSession}
type mediaSessionAction = MediaSessionTypes.mediaSessionAction
type mediaPositionState = MediaSessionTypes.mediaPositionState = {
  ...MediaSessionTypes.mediaPositionState,
}
type mediaSessionActionHandler = MediaSessionTypes.mediaSessionActionHandler

@send
external setActionHandler: (
  t,
  ~action: mediaSessionAction,
  ~handler: mediaSessionActionHandler,
) => unit = "setActionHandler"

@send
external setPositionState: (t, ~state: mediaPositionState=?) => unit = "setPositionState"

module MediaMetadata = MediaMetadata
module Types = MediaSessionTypes
