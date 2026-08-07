module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asBaseAudioContext: T.t => WebAudioTypes.baseAudioContext = "%identity"

  @send
  external createAnalyser: T.t => WebAudioTypes.analyserNode = "createAnalyser"

  @send
  external createBiquadFilter: T.t => WebAudioTypes.biquadFilterNode = "createBiquadFilter"

  @send
  external createBuffer: (
    T.t,
    ~numberOfChannels: int,
    ~length: int,
    ~sampleRate: float,
  ) => WebAudioTypes.audioBuffer = "createBuffer"

  @send
  external createBufferSource: T.t => WebAudioTypes.audioBufferSourceNode = "createBufferSource"

  @send
  external createChannelMerger: (T.t, ~numberOfInputs: int=?) => WebAudioTypes.channelMergerNode =
    "createChannelMerger"

  @send
  external createChannelSplitter: (
    T.t,
    ~numberOfOutputs: int=?,
  ) => WebAudioTypes.channelSplitterNode = "createChannelSplitter"

  @send
  external createConstantSource: T.t => WebAudioTypes.constantSourceNode = "createConstantSource"

  @send
  external createConvolver: T.t => WebAudioTypes.convolverNode = "createConvolver"

  @send
  external createDelay: (T.t, ~maxDelayTime: float=?) => WebAudioTypes.delayNode = "createDelay"

  @send
  external createDynamicsCompressor: T.t => WebAudioTypes.dynamicsCompressorNode =
    "createDynamicsCompressor"

  @send
  external createGain: T.t => WebAudioTypes.gainNode = "createGain"

  @send
  external createIIRFilter: (
    T.t,
    ~feedforward: array<float>,
    ~feedback: array<float>,
  ) => WebAudioTypes.iirFilterNode = "createIIRFilter"

  @send
  external createOscillator: T.t => WebAudioTypes.oscillatorNode = "createOscillator"

  @send
  external createPanner: T.t => WebAudioTypes.pannerNode = "createPanner"

  @send
  external createPeriodicWave: (
    T.t,
    ~real: array<float>,
    ~imag: array<float>,
    ~constraints: WebAudioTypes.periodicWaveConstraints=?,
  ) => WebAudioTypes.periodicWave = "createPeriodicWave"

  @send
  external createStereoPanner: T.t => WebAudioTypes.stereoPannerNode = "createStereoPanner"

  @send
  external createWaveShaper: T.t => WebAudioTypes.waveShaperNode = "createWaveShaper"

  @send
  external decodeAudioData: (
    T.t,
    ~audioData: ArrayBuffer.t,
    ~successCallback: WebAudioTypes.decodeSuccessCallback=?,
    ~errorCallback: WebAudioTypes.decodeErrorCallback=?,
  ) => promise<WebAudioTypes.audioBuffer> = "decodeAudioData"
}
