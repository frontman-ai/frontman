open WebAudioAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setValueAtTime)
*/
@send
external setValueAtTime: (audioParam, ~value: float, ~startTime: float) => audioParam =
  "setValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/linearRampToValueAtTime)
*/
@send
external linearRampToValueAtTime: (audioParam, ~value: float, ~endTime: float) => audioParam =
  "linearRampToValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/exponentialRampToValueAtTime)
*/
@send
external exponentialRampToValueAtTime: (audioParam, ~value: float, ~endTime: float) => audioParam =
  "exponentialRampToValueAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setTargetAtTime)
*/
@send
external setTargetAtTime: (
  audioParam,
  ~target: float,
  ~startTime: float,
  ~timeConstant: float,
) => audioParam = "setTargetAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/setValueCurveAtTime)
*/
@send
external setValueCurveAtTime: (
  audioParam,
  ~values: array<float>,
  ~startTime: float,
  ~duration: float,
) => audioParam = "setValueCurveAtTime"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/cancelScheduledValues)
*/
@send
external cancelScheduledValues: (audioParam, float) => audioParam = "cancelScheduledValues"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/cancelAndHoldAtTime)
*/
@send
external cancelAndHoldAtTime: (audioParam, float) => audioParam = "cancelAndHoldAtTime"
