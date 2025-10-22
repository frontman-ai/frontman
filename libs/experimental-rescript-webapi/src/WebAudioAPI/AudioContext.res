open WebAudioAPI
open DOMAPI
open MediaCaptureAndStreamsAPI

include BaseAudioContext.Impl({type t = audioContext})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext)
*/
@new
external make: (~contextOptions: audioContextOptions=?) => audioContext = "AudioContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/getOutputTimestamp)
*/
@send
external getOutputTimestamp: audioContext => audioTimestamp = "getOutputTimestamp"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/resume)
*/
@send
external resume: audioContext => promise<unit> = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/suspend)
*/
@send
external suspend: audioContext => promise<unit> = "suspend"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/close)
*/
@send
external close: audioContext => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaElementSource)
*/
@send
external createMediaElementSource: (audioContext, htmlMediaElement) => mediaElementAudioSourceNode =
  "createMediaElementSource"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaStreamSource)
*/
@send
external createMediaStreamSource: (audioContext, mediaStream) => mediaStreamAudioSourceNode =
  "createMediaStreamSource"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaStreamDestination)
*/
@send
external createMediaStreamDestination: audioContext => mediaStreamAudioDestinationNode =
  "createMediaStreamDestination"
