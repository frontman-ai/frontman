@new
external make: (~init: DomTypes.videoColorSpaceInit=?) => DomTypes.videoColorSpace =
  "VideoColorSpace"

@send
external toJSON: DomTypes.videoColorSpace => DomTypes.videoColorSpaceInit = "toJSON"
