@@warning("-30")

open EventAPI

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

/**
[See TextTrackCueList on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCueList)
*/
@editor.completeFrom(TextTrackCueList)
type textTrackCueList = {
  /**
    Returns the number of cues in the list.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCueList/length)
    */
  length: int,
}

/**
TextTrackCues represent a string of text that will be displayed for some duration of time on a TextTrack. This includes the start and end times that the cue will be displayed. A TextTrackCue cannot be used directly, instead one of the derived types (e.g. VTTCue) must be used.
[See TextTrackCue on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue)
*/
@editor.completeFrom(TextTrack)
type rec textTrackCue = {
  ...eventTarget,
  /**
    Returns the TextTrack object to which this text track cue belongs, if any, or null otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue/track)
    */
  track: Null.t<textTrack>,
  /**
    Returns the text track cue identifier.

Can be set.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue/id)
    */
  mutable id: string,
  /**
    Returns the text track cue start time, in seconds.

Can be set.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue/startTime)
    */
  mutable startTime: float,
  /**
    Returns the text track cue end time, in seconds.

Can be set.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue/endTime)
    */
  mutable endTime: float,
  /**
    Returns true if the text track cue pause-on-exit flag is set, false otherwise.

Can be set.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrackCue/pauseOnExit)
    */
  mutable pauseOnExit: bool,
}

/**
This interface also inherits properties from EventTarget.
[See TextTrack on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack)
*/
@editor.completeFrom(TextTrack) and textTrack = {
  ...eventTarget,
  /**
    Returns the text track kind string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/kind)
    */
  kind: textTrackKind,
  /**
    Returns the text track label, if there is one, or the empty string otherwise (indicating that a custom label probably needs to be generated from the other attributes of the object if the object is exposed to the user).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/label)
    */
  label: string,
  /**
    Returns the text track language string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/language)
    */
  language: string,
  /**
    Returns the ID of the given track.

For in-band tracks, this is the ID that can be used with a fragment if the format supports media fragment syntax, and that can be used with the getTrackById() method.

For TextTrack objects corresponding to track elements, this is the ID of the track element.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/id)
    */
  id: string,
  /**
    Returns the text track in-band metadata track dispatch type string.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/inBandMetadataTrackDispatchType)
    */
  inBandMetadataTrackDispatchType: string,
  /**
    Returns the text track mode, represented by a string from the following list:

Can be set, to change the mode.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/mode)
    */
  mutable mode: textTrackMode,
  /**
    Returns the text track list of cues, as a TextTrackCueList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/cues)
    */
  cues: Null.t<textTrackCueList>,
  /**
    Returns the text track cues from the text track list of cues that are currently active (i.e. that start before the current playback position and end after it), as a TextTrackCueList object.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextTrack/activeCues)
    */
  activeCues: Null.t<textTrackCueList>,
}
