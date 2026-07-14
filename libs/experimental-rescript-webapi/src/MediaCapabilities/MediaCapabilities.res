/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaCapabilities/decodingInfo)
*/
@send
external decodingInfo: (
  MediaCapabilitiesTypes.mediaCapabilities,
  MediaCapabilitiesTypes.mediaDecodingConfiguration,
) => promise<MediaCapabilitiesTypes.mediaCapabilitiesDecodingInfo> = "decodingInfo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaCapabilities/encodingInfo)
*/
@send
external encodingInfo: (
  MediaCapabilitiesTypes.mediaCapabilities,
  MediaCapabilitiesTypes.mediaEncodingConfiguration,
) => promise<MediaCapabilitiesTypes.mediaCapabilitiesEncodingInfo> = "encodingInfo"

module Types = MediaCapabilitiesTypes
