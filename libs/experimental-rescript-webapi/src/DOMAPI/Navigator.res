open DOMAPI
open FileAPI
open FetchAPI
open URLAPI
open EncryptedMediaExtensionsAPI
open GamepadAPI
open WebMIDIAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/setAppBadge)
*/
@send
external setAppBadge: (navigator, ~contents: int=?) => promise<unit> = "setAppBadge"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/clearAppBadge)
*/
@send
external clearAppBadge: navigator => promise<unit> = "clearAppBadge"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/registerProtocolHandler)
*/
@send
external registerProtocolHandler: (navigator, ~scheme: string, ~url: string) => unit =
  "registerProtocolHandler"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon: (navigator, ~url: string, ~data: readableStream<unit>=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon2: (navigator, ~url: string, ~data: blob=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon3: (navigator, ~url: string, ~data: DataView.t=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon4: (navigator, ~url: string, ~data: ArrayBuffer.t=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon5: (navigator, ~url: string, ~data: formData=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon6: (navigator, ~url: string, ~data: urlSearchParams=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/sendBeacon)
*/
@send
external sendBeacon7: (navigator, ~url: string, ~data: string=?) => bool = "sendBeacon"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/requestMediaKeySystemAccess)
*/
@send
external requestMediaKeySystemAccess: (
  navigator,
  ~keySystem: string,
  ~supportedConfigurations: array<mediaKeySystemConfiguration>,
) => promise<mediaKeySystemAccess> = "requestMediaKeySystemAccess"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/getGamepads)
*/
@send
external getGamepads: navigator => array<gamepad> = "getGamepads"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/vibrate)
*/
@send
external vibrate: (navigator, int) => bool = "vibrate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/vibrate)
*/
@send
external vibrate2: (navigator, array<int>) => bool = "vibrate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/share)
*/
@send
external share: (navigator, ~data: shareData=?) => promise<unit> = "share"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/canShare)
*/
@send
external canShare: (navigator, ~data: shareData=?) => bool = "canShare"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigator/requestMIDIAccess)
*/
@send
external requestMIDIAccess: (navigator, ~options: midiOptions=?) => promise<midiAccess> =
  "requestMIDIAccess"
