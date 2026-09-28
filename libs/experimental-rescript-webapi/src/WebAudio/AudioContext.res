include BaseAudioContext.Impl({type t = WebAudioTypes.audioContext})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext)
*/
@new
external make: (
  ~contextOptions: WebAudioTypes.audioContextOptions=?,
) => WebAudioTypes.audioContext = "AudioContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/getOutputTimestamp)
*/
@send
external getOutputTimestamp: WebAudioTypes.audioContext => WebAudioTypes.audioTimestamp =
  "getOutputTimestamp"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/resume)
*/
@send
external resume: WebAudioTypes.audioContext => promise<unit> = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/suspend)
*/
@send
external suspend: WebAudioTypes.audioContext => promise<unit> = "suspend"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/close)
*/
@send
external close: WebAudioTypes.audioContext => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaElementSource)
*/
@send
external createMediaElementSource: (
  WebAudioTypes.audioContext,
  DomTypes.htmlMediaElement,
) => WebAudioTypes.mediaElementAudioSourceNode = "createMediaElementSource"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaStreamSource)
*/
@send
external createMediaStreamSource: (
  WebAudioTypes.audioContext,
  MediaCaptureAndStreamsTypes.mediaStream,
) => WebAudioTypes.mediaStreamAudioSourceNode = "createMediaStreamSource"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/createMediaStreamDestination)
*/
@send
external createMediaStreamDestination: WebAudioTypes.audioContext => WebAudioTypes.mediaStreamAudioDestinationNode =
  "createMediaStreamDestination"
