type t = MediaSessionTypes.mediaMetadata = private {...MediaSessionTypes.mediaMetadata}
type mediaMetadataInit = MediaSessionTypes.mediaMetadataInit = {
  ...MediaSessionTypes.mediaMetadataInit,
}

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaMetadata)
*/
@new
external make: (~init: mediaMetadataInit=?) => t = "MediaMetadata"
