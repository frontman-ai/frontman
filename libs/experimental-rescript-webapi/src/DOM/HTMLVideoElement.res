include DomHTMLMediaElement.Impl({type t = DomTypes.htmlVideoElement})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/getVideoPlaybackQuality)
*/
@send
external getVideoPlaybackQuality: DomTypes.htmlVideoElement => DomTypes.videoPlaybackQuality =
  "getVideoPlaybackQuality"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/requestPictureInPicture)
*/
@send
external requestPictureInPicture: DomTypes.htmlVideoElement => promise<
  PictureInPictureTypes.pictureInPictureWindow,
> = "requestPictureInPicture"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/requestVideoFrameCallback)
*/
@send
external requestVideoFrameCallback: (
  DomTypes.htmlVideoElement,
  (float, DomTypes.videoFrameCallbackMetadata) => unit,
) => int = "requestVideoFrameCallback"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLVideoElement/cancelVideoFrameCallback)
*/
@send
external cancelVideoFrameCallback: (DomTypes.htmlVideoElement, int) => unit =
  "cancelVideoFrameCallback"
