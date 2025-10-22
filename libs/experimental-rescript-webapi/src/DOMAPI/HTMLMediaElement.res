open DOMAPI
open WebVTTAPI
open EncryptedMediaExtensionsAPI

module Impl = (
  T: {
    type t
  },
) => {
  include HTMLElement.Impl({type t = htmlMediaElement})

  external asHTMLMediaElement: T.t => htmlMediaElement = "%identity"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/addTextTrack)
*/
  @send
  external addTextTrack: (
    T.t,
    ~kind: textTrackKind,
    ~label: string=?,
    ~language: string=?,
  ) => textTrack = "addTextTrack"

  /**
Returns a string that specifies whether the client can play a given media resource type.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/canPlayType)
*/
  @send
  external canPlayType: (T.t, string) => canPlayTypeResult = "canPlayType"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/fastSeek)
*/
  @send
  external fastSeek: (T.t, float) => unit = "fastSeek"

  /**
Resets the audio or video object and loads a new media resource.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/load)
*/
  @send
  external load: T.t => unit = "load"

  /**
Pauses the current playback and sets paused to TRUE.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/pause)
*/
  @send
  external pause: T.t => unit = "pause"

  /**
Loads and starts playback of a media resource.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/play)
*/
  @send
  external play: T.t => promise<unit> = "play"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/setMediaKeys)
*/
  @send
  external setMediaKeys: (T.t, mediaKeys) => promise<unit> = "setMediaKeys"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLMediaElement/setSinkId)
*/
  @send
  external setSinkId: (T.t, string) => promise<unit> = "setSinkId"
}

include Impl({type t = htmlMediaElement})
