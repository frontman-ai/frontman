open WebVTTAPI

include EventTarget.Impl({type t = textTrack})

/**
Adds the given cue to textTrack's text track list of cues.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/addCue)
*/
@send
external addCue: (textTrack, textTrackCue) => unit = "addCue"

/**
Removes the given cue from textTrack's text track list of cues.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/removeCue)
*/
@send
external removeCue: (textTrack, textTrackCue) => unit = "removeCue"
