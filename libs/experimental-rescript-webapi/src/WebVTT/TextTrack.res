include EventTarget.Impl({type t = WebVttTypes.textTrack})

@send
external addCue: (WebVttTypes.textTrack, WebVttTypes.textTrackCue) => unit = "addCue"

@send
external removeCue: (WebVttTypes.textTrack, WebVttTypes.textTrackCue) => unit = "removeCue"
