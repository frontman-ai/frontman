@send
external setValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~startTime: float,
) => WebAudioTypes.audioParam = "setValueAtTime"

@send
external linearRampToValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~endTime: float,
) => WebAudioTypes.audioParam = "linearRampToValueAtTime"

@send
external exponentialRampToValueAtTime: (
  WebAudioTypes.audioParam,
  ~value: float,
  ~endTime: float,
) => WebAudioTypes.audioParam = "exponentialRampToValueAtTime"

@send
external setTargetAtTime: (
  WebAudioTypes.audioParam,
  ~target: float,
  ~startTime: float,
  ~timeConstant: float,
) => WebAudioTypes.audioParam = "setTargetAtTime"

@send
external setValueCurveAtTime: (
  WebAudioTypes.audioParam,
  ~values: array<float>,
  ~startTime: float,
  ~duration: float,
) => WebAudioTypes.audioParam = "setValueCurveAtTime"

@send
external cancelScheduledValues: (WebAudioTypes.audioParam, float) => WebAudioTypes.audioParam =
  "cancelScheduledValues"

@send
external cancelAndHoldAtTime: (WebAudioTypes.audioParam, float) => WebAudioTypes.audioParam =
  "cancelAndHoldAtTime"
