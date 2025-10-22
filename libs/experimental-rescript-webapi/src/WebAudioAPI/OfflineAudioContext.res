open WebAudioAPI

include BaseAudioContext.Impl({type t = offlineAudioContext})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext)
*/
@new
external make: offlineAudioContextOptions => offlineAudioContext = "OfflineAudioContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext)
*/
@new
external make2: (~numberOfChannels: int, ~length: int, ~sampleRate: float) => offlineAudioContext =
  "OfflineAudioContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/startRendering)
*/
@send
external startRendering: offlineAudioContext => promise<audioBuffer> = "startRendering"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/resume)
*/
@send
external resume: offlineAudioContext => promise<unit> = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/suspend)
*/
@send
external suspend: (offlineAudioContext, float) => promise<unit> = "suspend"
