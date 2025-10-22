open WebVTTAPI

/**
Returns the first text track cue (in text track cue order) with text track cue identifier id.

Returns null if none of the cues have the given identifier or if the argument is the empty string.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCueList/getCueById)
*/
@send
external getCueById: (textTrackCueList, string) => textTrackCue = "getCueById"
