@new
external make: WebAudioTypes.audioBufferOptions => WebAudioTypes.audioBuffer = "AudioBuffer"

@send
external getChannelData: (WebAudioTypes.audioBuffer, int) => array<float> = "getChannelData"

@send
external copyFromChannel: (
  WebAudioTypes.audioBuffer,
  ~destination: array<float>,
  ~channelNumber: int,
  ~bufferOffset: int=?,
) => unit = "copyFromChannel"

@send
external copyToChannel: (
  WebAudioTypes.audioBuffer,
  ~source: array<float>,
  ~channelNumber: int,
  ~bufferOffset: int=?,
) => unit = "copyToChannel"
