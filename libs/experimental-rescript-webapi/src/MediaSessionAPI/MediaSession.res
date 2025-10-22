open MediaSessionAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaSession/setActionHandler)
*/
@send
external setActionHandler: (
  mediaSession,
  ~action: mediaSessionAction,
  ~handler: mediaSessionActionHandler,
) => unit = "setActionHandler"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaSession/setPositionState)
*/
@send
external setPositionState: (mediaSession, ~state: mediaPositionState=?) => unit = "setPositionState"
