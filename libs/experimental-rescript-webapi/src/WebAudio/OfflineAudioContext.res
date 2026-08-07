include BaseAudioContext.Impl({type t = WebAudioTypes.offlineAudioContext})

@new
external fromOptions: WebAudioTypes.offlineAudioContextOptions => WebAudioTypes.offlineAudioContext =
  "OfflineAudioContext"

@new
external fromChannelCountLengthAndSampleRate: (
  ~numberOfChannels: int,
  ~length: int,
  ~sampleRate: float,
) => WebAudioTypes.offlineAudioContext = "OfflineAudioContext"

@send
external startRendering: WebAudioTypes.offlineAudioContext => promise<WebAudioTypes.audioBuffer> =
  "startRendering"

@send
external resume: WebAudioTypes.offlineAudioContext => promise<unit> = "resume"

@send
external suspend: (WebAudioTypes.offlineAudioContext, float) => promise<unit> = "suspend"
