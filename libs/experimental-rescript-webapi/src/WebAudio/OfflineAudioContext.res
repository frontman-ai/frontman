include BaseAudioContext.Impl({type t = WebAudioTypes.offlineAudioContext})

/**
`fromOptions(offlineAudioContextOptions)`

Creates a new `OfflineAudioContext` from `offlineAudioContextOptions`.

```res
let context = OfflineAudioContext.fromOptions(myOfflineAudioContextOptions)
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext)
*/
@new
external fromOptions: WebAudioTypes.offlineAudioContextOptions => WebAudioTypes.offlineAudioContext =
  "OfflineAudioContext"

/**
`fromChannelCountLengthAndSampleRate(~numberOfChannels: int, ~length: int, ~sampleRate: float)`

Creates a new `OfflineAudioContext` from explicit channel, length, and sample-rate values.

```res
let context =
  OfflineAudioContext.fromChannelCountLengthAndSampleRate(
    ~numberOfChannels=2,
    ~length=44_100,
    ~sampleRate=44_100.,
  )
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext)
*/
@new
external fromChannelCountLengthAndSampleRate: (
  ~numberOfChannels: int,
  ~length: int,
  ~sampleRate: float,
) => WebAudioTypes.offlineAudioContext = "OfflineAudioContext"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/startRendering)
*/
@send
external startRendering: WebAudioTypes.offlineAudioContext => promise<WebAudioTypes.audioBuffer> =
  "startRendering"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/resume)
*/
@send
external resume: WebAudioTypes.offlineAudioContext => promise<unit> = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/suspend)
*/
@send
external suspend: (WebAudioTypes.offlineAudioContext, float) => promise<unit> = "suspend"
