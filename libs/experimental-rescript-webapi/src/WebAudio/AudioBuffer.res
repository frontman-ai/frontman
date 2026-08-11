/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer)
*/
@new
external make: WebAudioTypes.audioBufferOptions => WebAudioTypes.audioBuffer = "AudioBuffer"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/getChannelData)
*/
@send
external getChannelData: (WebAudioTypes.audioBuffer, int) => array<float> = "getChannelData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/copyFromChannel)
*/
@send
external copyFromChannel: (
  WebAudioTypes.audioBuffer,
  ~destination: array<float>,
  ~channelNumber: int,
  ~bufferOffset: int=?,
) => unit = "copyFromChannel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/copyToChannel)
*/
@send
external copyToChannel: (
  WebAudioTypes.audioBuffer,
  ~source: array<float>,
  ~channelNumber: int,
  ~bufferOffset: int=?,
) => unit = "copyToChannel"
