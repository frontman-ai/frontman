@@warning("-30")

type textTrackKind =
  | @as("captions") Captions
  | @as("chapters") Chapters
  | @as("descriptions") Descriptions
  | @as("metadata") Metadata
  | @as("subtitles") Subtitles

type textTrackMode =
  | @as("disabled") Disabled
  | @as("hidden") Hidden
  | @as("showing") Showing

@editor.completeFrom(TextTrackCueList)
type textTrackCueList = private {
  length: int,
}

@editor.completeFrom(TextTrack)
type rec textTrackCue = {
  ...EventTypes.eventTarget,
  track: Null.t<textTrack>,
  mutable id: string,
  mutable startTime: float,
  mutable endTime: float,
  mutable pauseOnExit: bool,
}

@editor.completeFrom(TextTrack)
and textTrack = {
  ...EventTypes.eventTarget,
  kind: textTrackKind,
  label: string,
  language: string,
  id: string,
  inBandMetadataTrackDispatchType: string,
  mutable mode: textTrackMode,
  cues: Null.t<textTrackCueList>,
  activeCues: Null.t<textTrackCueList>,
}
