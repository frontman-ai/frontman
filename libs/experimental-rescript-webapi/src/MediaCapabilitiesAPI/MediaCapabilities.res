open MediaCapabilitiesAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaCapabilities/decodingInfo)
*/
@send
external decodingInfo: (
  mediaCapabilities,
  mediaDecodingConfiguration,
) => promise<mediaCapabilitiesDecodingInfo> = "decodingInfo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaCapabilities/encodingInfo)
*/
@send
external encodingInfo: (
  mediaCapabilities,
  mediaEncodingConfiguration,
) => promise<mediaCapabilitiesEncodingInfo> = "encodingInfo"
