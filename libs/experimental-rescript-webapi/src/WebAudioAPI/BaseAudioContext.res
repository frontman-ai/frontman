open WebAudioAPI

module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asBaseAudioContext: T.t => baseAudioContext = "%identity"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createAnalyser)
*/
  @send
  external createAnalyser: T.t => analyserNode = "createAnalyser"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBiquadFilter)
*/
  @send
  external createBiquadFilter: T.t => biquadFilterNode = "createBiquadFilter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBuffer)
*/
  @send
  external createBuffer: (
    T.t,
    ~numberOfChannels: int,
    ~length: int,
    ~sampleRate: float,
  ) => audioBuffer = "createBuffer"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBufferSource)
*/
  @send
  external createBufferSource: T.t => audioBufferSourceNode = "createBufferSource"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createChannelMerger)
*/
  @send
  external createChannelMerger: (T.t, ~numberOfInputs: int=?) => channelMergerNode =
    "createChannelMerger"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createChannelSplitter)
*/
  @send
  external createChannelSplitter: (T.t, ~numberOfOutputs: int=?) => channelSplitterNode =
    "createChannelSplitter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createConstantSource)
*/
  @send
  external createConstantSource: T.t => constantSourceNode = "createConstantSource"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createConvolver)
*/
  @send
  external createConvolver: T.t => convolverNode = "createConvolver"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createDelay)
*/
  @send
  external createDelay: (T.t, ~maxDelayTime: float=?) => delayNode = "createDelay"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createDynamicsCompressor)
*/
  @send
  external createDynamicsCompressor: T.t => dynamicsCompressorNode = "createDynamicsCompressor"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createGain)
*/
  @send
  external createGain: T.t => gainNode = "createGain"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createIIRFilter)
*/
  @send
  external createIIRFilter: (
    T.t,
    ~feedforward: array<float>,
    ~feedback: array<float>,
  ) => iirFilterNode = "createIIRFilter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createOscillator)
*/
  @send
  external createOscillator: T.t => oscillatorNode = "createOscillator"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createPanner)
*/
  @send
  external createPanner: T.t => pannerNode = "createPanner"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createPeriodicWave)
*/
  @send
  external createPeriodicWave: (
    T.t,
    ~real: array<float>,
    ~imag: array<float>,
    ~constraints: periodicWaveConstraints=?,
  ) => periodicWave = "createPeriodicWave"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createStereoPanner)
*/
  @send
  external createStereoPanner: T.t => stereoPannerNode = "createStereoPanner"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createWaveShaper)
*/
  @send
  external createWaveShaper: T.t => waveShaperNode = "createWaveShaper"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/decodeAudioData)
*/
  @send
  external decodeAudioData: (
    T.t,
    ~audioData: ArrayBuffer.t,
    ~successCallback: decodeSuccessCallback=?,
    ~errorCallback: decodeErrorCallback=?,
  ) => promise<audioBuffer> = "decodeAudioData"
}
