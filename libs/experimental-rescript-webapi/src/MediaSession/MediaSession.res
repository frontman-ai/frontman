type t = MediaSessionTypes.mediaSession = private {...MediaSessionTypes.mediaSession}
type mediaSessionAction = MediaSessionTypes.mediaSessionAction
type mediaPositionState = MediaSessionTypes.mediaPositionState = {
  ...MediaSessionTypes.mediaPositionState,
}
type mediaSessionActionHandler = MediaSessionTypes.mediaSessionActionHandler

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaSession/setActionHandler)
*/
@send
external setActionHandler: (
  t,
  ~action: mediaSessionAction,
  ~handler: mediaSessionActionHandler,
) => unit = "setActionHandler"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaSession/setPositionState)
*/
@send
external setPositionState: (t, ~state: mediaPositionState=?) => unit = "setPositionState"

module MediaMetadata = MediaMetadata
module Types = MediaSessionTypes
