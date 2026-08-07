include BaseAudioContext.Impl({type t = WebAudioTypes.audioContext})

@new
external make: (
  ~contextOptions: WebAudioTypes.audioContextOptions=?,
) => WebAudioTypes.audioContext = "AudioContext"

@send
external getOutputTimestamp: WebAudioTypes.audioContext => WebAudioTypes.audioTimestamp =
  "getOutputTimestamp"

@send
external resume: WebAudioTypes.audioContext => promise<unit> = "resume"

@send
external suspend: WebAudioTypes.audioContext => promise<unit> = "suspend"

@send
external close: WebAudioTypes.audioContext => promise<unit> = "close"

@send
external createMediaElementSource: (
  WebAudioTypes.audioContext,
  DomTypes.htmlMediaElement,
) => WebAudioTypes.mediaElementAudioSourceNode = "createMediaElementSource"

@send
external createMediaStreamSource: (
  WebAudioTypes.audioContext,
  MediaCaptureAndStreamsTypes.mediaStream,
) => WebAudioTypes.mediaStreamAudioSourceNode = "createMediaStreamSource"

@send
external createMediaStreamDestination: WebAudioTypes.audioContext => WebAudioTypes.mediaStreamAudioDestinationNode =
  "createMediaStreamDestination"
