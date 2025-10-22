@@warning("-30")
type hdrMetadataType =
  | @as("smpteSt2086") SmpteSt2086
  | @as("smpteSt2094-10") SmpteSt209410
  | @as("smpteSt2094-40") SmpteSt209440

type colorGamut =
  | @as("p3") P3
  | @as("rec2020") Rec2020
  | @as("srgb") Srgb

type transferFunction =
  | @as("hlg") Hlg
  | @as("pq") Pq
  | @as("srgb") Srgb

type mediaDecodingType =
  | @as("file") File
  | @as("media-source") MediaSource
  | @as("webrtc") Webrtc

type mediaEncodingType =
  | @as("record") Record
  | @as("webrtc") Webrtc

/**
[See MediaCapabilities on MDN](https://developer.mozilla.org/docs/Web/API/MediaCapabilities)
*/
@editor.completeFrom(MediaCapabilities)
type mediaCapabilities = {}

type audioConfiguration = {
  mutable contentType: string,
  mutable channels?: string,
  mutable bitrate?: int,
  mutable samplerate?: int,
  mutable spatialRendering?: bool,
}

type videoConfiguration = {
  mutable contentType: string,
  mutable width: int,
  mutable height: int,
  mutable bitrate: int,
  mutable framerate: float,
  mutable hasAlphaChannel?: bool,
  mutable hdrMetadataType?: hdrMetadataType,
  mutable colorGamut?: colorGamut,
  mutable transferFunction?: transferFunction,
  mutable scalabilityMode?: string,
}

type mediaConfiguration = {
  mutable video?: videoConfiguration,
  mutable audio?: audioConfiguration,
}

type mediaDecodingConfiguration = {
  ...mediaConfiguration,
  @as("type") mutable type_: mediaDecodingType,
}

type mediaCapabilitiesInfo = {
  mutable supported: bool,
  mutable smooth: bool,
  mutable powerEfficient: bool,
}

type mediaCapabilitiesDecodingInfo = {
  ...mediaCapabilitiesInfo,
  mutable configuration?: mediaDecodingConfiguration,
}

type mediaEncodingConfiguration = {
  ...mediaConfiguration,
  @as("type") mutable type_: mediaEncodingType,
}

type mediaCapabilitiesEncodingInfo = {
  ...mediaCapabilitiesInfo,
  mutable configuration?: mediaEncodingConfiguration,
}
