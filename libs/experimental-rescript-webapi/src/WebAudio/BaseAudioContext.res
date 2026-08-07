module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asBaseAudioContext: T.t => WebAudioTypes.baseAudioContext = "%identity"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createAnalyser)
*/
  @send
  external createAnalyser: T.t => WebAudioTypes.analyserNode = "createAnalyser"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBiquadFilter)
*/
  @send
  external createBiquadFilter: T.t => WebAudioTypes.biquadFilterNode = "createBiquadFilter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBuffer)
*/
  @send
  external createBuffer: (
    T.t,
    ~numberOfChannels: int,
    ~length: int,
    ~sampleRate: float,
  ) => WebAudioTypes.audioBuffer = "createBuffer"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createBufferSource)
*/
  @send
  external createBufferSource: T.t => WebAudioTypes.audioBufferSourceNode = "createBufferSource"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createChannelMerger)
*/
  @send
  external createChannelMerger: (T.t, ~numberOfInputs: int=?) => WebAudioTypes.channelMergerNode =
    "createChannelMerger"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createChannelSplitter)
*/
  @send
  external createChannelSplitter: (
    T.t,
    ~numberOfOutputs: int=?,
  ) => WebAudioTypes.channelSplitterNode = "createChannelSplitter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createConstantSource)
*/
  @send
  external createConstantSource: T.t => WebAudioTypes.constantSourceNode = "createConstantSource"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createConvolver)
*/
  @send
  external createConvolver: T.t => WebAudioTypes.convolverNode = "createConvolver"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createDelay)
*/
  @send
  external createDelay: (T.t, ~maxDelayTime: float=?) => WebAudioTypes.delayNode = "createDelay"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createDynamicsCompressor)
*/
  @send
  external createDynamicsCompressor: T.t => WebAudioTypes.dynamicsCompressorNode =
    "createDynamicsCompressor"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createGain)
*/
  @send
  external createGain: T.t => WebAudioTypes.gainNode = "createGain"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createIIRFilter)
*/
  @send
  external createIIRFilter: (
    T.t,
    ~feedforward: array<float>,
    ~feedback: array<float>,
  ) => WebAudioTypes.iirFilterNode = "createIIRFilter"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createOscillator)
*/
  @send
  external createOscillator: T.t => WebAudioTypes.oscillatorNode = "createOscillator"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createPanner)
*/
  @send
  external createPanner: T.t => WebAudioTypes.pannerNode = "createPanner"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createPeriodicWave)
*/
  @send
  external createPeriodicWave: (
    T.t,
    ~real: array<float>,
    ~imag: array<float>,
    ~constraints: WebAudioTypes.periodicWaveConstraints=?,
  ) => WebAudioTypes.periodicWave = "createPeriodicWave"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createStereoPanner)
*/
  @send
  external createStereoPanner: T.t => WebAudioTypes.stereoPannerNode = "createStereoPanner"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/createWaveShaper)
*/
  @send
  external createWaveShaper: T.t => WebAudioTypes.waveShaperNode = "createWaveShaper"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/decodeAudioData)
*/
  @send
  external decodeAudioData: (
    T.t,
    ~audioData: ArrayBuffer.t,
    ~successCallback: WebAudioTypes.decodeSuccessCallback=?,
    ~errorCallback: WebAudioTypes.decodeErrorCallback=?,
  ) => promise<WebAudioTypes.audioBuffer> = "decodeAudioData"
}
