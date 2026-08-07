include DomHTMLMediaElement.Impl({type t = DomTypes.htmlVideoElement})

@send
external getVideoPlaybackQuality: DomTypes.htmlVideoElement => DomTypes.videoPlaybackQuality =
  "getVideoPlaybackQuality"

@send
external requestPictureInPicture: DomTypes.htmlVideoElement => promise<
  PictureInPictureTypes.pictureInPictureWindow,
> = "requestPictureInPicture"

@send
external requestVideoFrameCallback: (
  DomTypes.htmlVideoElement,
  (float, DomTypes.videoFrameCallbackMetadata) => unit,
) => int = "requestVideoFrameCallback"

@send
external cancelVideoFrameCallback: (DomTypes.htmlVideoElement, int) => unit =
  "cancelVideoFrameCallback"
