include EventTarget.Impl({type t = DomTypes.textTrackList})

@send
external getTrackById: (DomTypes.textTrackList, string) => WebVttTypes.textTrack = "getTrackById"
