open DOMAPI
open WebVTTAPI

include EventTarget.Impl({type t = textTrackList})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackList/getTrackById)
*/
@send
external getTrackById: (textTrackList, string) => textTrack = "getTrackById"
