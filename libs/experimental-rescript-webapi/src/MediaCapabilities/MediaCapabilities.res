@send
external decodingInfo: (
  MediaCapabilitiesTypes.mediaCapabilities,
  MediaCapabilitiesTypes.mediaDecodingConfiguration,
) => promise<MediaCapabilitiesTypes.mediaCapabilitiesDecodingInfo> = "decodingInfo"

@send
external encodingInfo: (
  MediaCapabilitiesTypes.mediaCapabilities,
  MediaCapabilitiesTypes.mediaEncodingConfiguration,
) => promise<MediaCapabilitiesTypes.mediaCapabilitiesEncodingInfo> = "encodingInfo"

module Types = MediaCapabilitiesTypes
