/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setValueAtTime)
*/
@send
external setValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~startTime: float,
) => WebAudioTypes.audioParam = "setValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/linearRampToValueAtTime)
*/
@send
external linearRampToValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~endTime: float,
) => WebAudioTypes.audioParam = "linearRampToValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/exponentialRampToValueAtTime)
*/
@send
external exponentialRampToValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~endTime: float,
) => WebAudioTypes.audioParam = "exponentialRampToValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setTargetAtTime)
*/
@send
external setTargetAtTime: (
  WebAudioTypes.audioParam,
  ~target: float,
  ~startTime: float,
  ~timeConstant: float,
) => WebAudioTypes.audioParam = "setTargetAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setValueCurveAtTime)
*/
@send
external setValueCurveAtTime: (
  WebAudioTypes.audioParam,
  ~values: array<float>,
  ~startTime: float,
  ~duration: float,
) => WebAudioTypes.audioParam = "setValueCurveAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/cancelScheduledValues)
*/
@send
external cancelScheduledValues: (WebAudioTypes.audioParam, float) => WebAudioTypes.audioParam =
  "cancelScheduledValues"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/cancelAndHoldAtTime)
*/
@send
external cancelAndHoldAtTime: (WebAudioTypes.audioParam, float) => WebAudioTypes.audioParam =
  "cancelAndHoldAtTime"
