module Impl = (
  T: {
    type t
  },
) => {
  include HTMLElement.Impl({type t = DomTypes.htmlMediaElement})

  external asHTMLMediaElement: T.t => DomTypes.htmlMediaElement = "%identity"

  @send
  external addTextTrack: (
    T.t,
    ~kind: WebVttTypes.textTrackKind,
    ~label: string=?,
    ~language: string=?,
  ) => WebVttTypes.textTrack = "addTextTrack"

  @send
  external canPlayType: (T.t, string) => DomTypes.canPlayTypeResult = "canPlayType"

  @send
  external fastSeek: (T.t, float) => unit = "fastSeek"

  @send
  external load: T.t => unit = "load"

  @send
  external pause: T.t => unit = "pause"

  @send
  external play: T.t => promise<unit> = "play"

  @send
  external setSinkId: (T.t, string) => promise<unit> = "setSinkId"
}

include Impl({type t = DomTypes.htmlMediaElement})
