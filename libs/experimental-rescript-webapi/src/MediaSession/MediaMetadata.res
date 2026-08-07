type t = MediaSessionTypes.mediaMetadata = private {...MediaSessionTypes.mediaMetadata}
type mediaMetadataInit = MediaSessionTypes.mediaMetadataInit = {
  ...MediaSessionTypes.mediaMetadataInit,
}

@new
external make: (~init: mediaMetadataInit=?) => t = "MediaMetadata"
