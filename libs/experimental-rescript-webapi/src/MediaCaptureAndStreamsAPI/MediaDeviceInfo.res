open MediaCaptureAndStreamsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaDeviceInfo/toJSON)
*/
@send
external toJSON: mediaDeviceInfo => Dict.t<string> = "toJSON"
