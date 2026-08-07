@@warning("-30")

type audioContextState =
  | @as("closed") Closed
  | @as("running") Running
  | @as("suspended") Suspended

type biquadFilterType =
  | @as("allpass") Allpass
  | @as("bandpass") Bandpass
  | @as("highpass") Highpass
  | @as("highshelf") Highshelf
  | @as("lowpass") Lowpass
  | @as("lowshelf") Lowshelf
  | @as("notch") Notch
  | @as("peaking") Peaking

type channelCountMode =
  | @as("clamped-max") ClampedMax
  | @as("explicit") Explicit
  | @as("max") Max

type channelInterpretation =
  | @as("discrete") Discrete
  | @as("speakers") Speakers

type oscillatorType =
  | @as("custom") Custom
  | @as("sawtooth") Sawtooth
  | @as("sine") Sine
  | @as("square") Square
  | @as("triangle") Triangle

type panningModelType =
  | HRTF
  | @as("equalpower") Equalpower

type distanceModelType =
  | @as("exponential") Exponential
  | @as("inverse") Inverse
  | @as("linear") Linear

type overSampleType =
  | @as("2x") V2x
  | @as("4x") V4x
  | @as("none") None

type requestCredentials =
  | @as("include") Include
  | @as("omit") Omit
  | @as("same-origin") SameOrigin

@editor.completeFrom(AudioBuffer)
type audioBuffer = private {
  sampleRate: float,
  length: int,
  duration: float,
  numberOfChannels: int,
}

@editor.completeFrom(AudioProcessingEvent)
type audioProcessingEvent = private {
  ...EventTypes.event,
}

@editor.completeFrom(OfflineAudioCompletionEvent)
type offlineAudioCompletionEvent = private {
  ...EventTypes.event,
  renderedBuffer: audioBuffer,
}

@editor.completeFrom(Worklet)
type worklet = private {}

@editor.completeFrom(AudioNode)
type rec audioNode = {
  ...EventTypes.eventTarget,
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
}

and audioDestinationNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  maxChannelCount: int,
}

@editor.completeFrom(BaseAudioContext)
and baseAudioContext = private {
  ...EventTypes.eventTarget,
  destination: audioDestinationNode,
  sampleRate: float,
  currentTime: float,
  listener: audioListener,
  state: audioContextState,
  audioWorklet: audioWorklet,
}

@editor.completeFrom(BiquadFilterNode)
and biquadFilterNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  @as("type")
  mutable type_: biquadFilterType,
  frequency: audioParam,
  detune: audioParam,
  @as("Q")
  q: audioParam,
  gain: audioParam,
}

and audioListener = {
  positionX: audioParam,
  positionY: audioParam,
  positionZ: audioParam,
  forwardX: audioParam,
  forwardY: audioParam,
  forwardZ: audioParam,
  upX: audioParam,
  upY: audioParam,
  upZ: audioParam,
}

and audioWorklet = {
  ...worklet,
}

@editor.completeFrom(AudioParam)
and audioParam = {
  mutable value: float,
  defaultValue: float,
  minValue: float,
  maxValue: float,
}

@editor.completeFrom(AudioScheduledSourceNode)
and audioScheduledSourceNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
}

@editor.completeFrom(AudioBufferSourceNode)
and audioBufferSourceNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  mutable buffer: Null.t<audioBuffer>,
  playbackRate: audioParam,
  detune: audioParam,
  mutable loop: bool,
  mutable loopStart: float,
  mutable loopEnd: float,
}

@editor.completeFrom(ChannelMergerNode)
and channelMergerNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
}

@editor.completeFrom(ChannelSplitterNode)
and channelSplitterNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
}

@editor.completeFrom(ConstantSourceNode)
and constantSourceNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  offset: audioParam,
}

@editor.completeFrom(ConvolverNode)
and convolverNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  mutable buffer: Null.t<audioBuffer>,
  mutable normalize: bool,
}

@editor.completeFrom(DelayNode)
and delayNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  delayTime: audioParam,
}

@editor.completeFrom(DynamicsCompressorNode)
and dynamicsCompressorNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  threshold: audioParam,
  knee: audioParam,
  ratio: audioParam,
  reduction: float,
  attack: audioParam,
  release: audioParam,
}

@editor.completeFrom(GainNode)
and gainNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  gain: audioParam,
}

@editor.completeFrom(IIRFilterNode)
and iirFilterNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
}

@editor.completeFrom(OscillatorNode)
and oscillatorNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  @as("type")
  mutable type_: oscillatorType,
  frequency: audioParam,
  detune: audioParam,
}

@editor.completeFrom(PannerNode)
and pannerNode = {
  context: baseAudioContext,
  numberOfInputs: int,
  numberOfOutputs: int,
  mutable channelCount: int,
  mutable channelCountMode: channelCountMode,
  mutable channelInterpretation: channelInterpretation,
  mutable panningModel: panningModelType,
  positionX: audioParam,
  positionY: audioParam,
  positionZ: audioParam,
  orientationX: audioParam,
  orientationY: audioParam,
  orientationZ: audioParam,
  mutable distanceModel: distanceModelType,
  mutable refDistance: float,
  mutable maxDistance: float,
  mutable rolloffFactor: float,
  mutable coneInnerAngle: float,
  mutable coneOuterAngle: float,
  mutable coneOuterGain: float,
}

@editor.completeFrom(AnalyserNode)
type analyserNode = {
  ...audioNode,
  mutable fftSize: int,
  frequencyBinCount: int,
  mutable minDecibels: float,
  mutable maxDecibels: float,
  mutable smoothingTimeConstant: float,
}

@editor.completeFrom(PeriodicWave)
type periodicWave = private {}

@editor.completeFrom(StereoPannerNode)
type stereoPannerNode = private {
  ...audioNode,
  pan: audioParam,
}

@editor.completeFrom(WaveShaperNode)
type waveShaperNode = {
  ...audioNode,
  mutable curve: Null.t<array<float>>,
  mutable oversample: overSampleType,
}

@editor.completeFrom(AudioContext)
type audioContext = private {
  ...baseAudioContext,
  baseLatency: float,
  outputLatency: float,
}

@editor.completeFrom(MediaElementAudioSourceNode)
type mediaElementAudioSourceNode = private {
  ...audioNode,
  mediaElement: DomTypes.htmlMediaElement,
}

@editor.completeFrom(MediaStreamAudioSourceNode)
type mediaStreamAudioSourceNode = private {
  ...audioNode,
  mediaStream: MediaCaptureAndStreamsTypes.mediaStream,
}

@editor.completeFrom(MediaStreamAudioDestinationNode)
type mediaStreamAudioDestinationNode = private {
  ...audioNode,
  stream: MediaCaptureAndStreamsTypes.mediaStream,
}

type audioParamMap = {}

@editor.completeFrom(AudioWorkletNode)
type audioWorkletNode = private {
  ...audioNode,
  parameters: audioParamMap,
  port: ChannelMessagingTypes.messagePort,
}

@editor.completeFrom(OfflineAudioContext)
type offlineAudioContext = private {
  ...baseAudioContext,
  length: int,
}

type periodicWaveConstraints = {mutable disableNormalization?: bool}

type audioTimestamp = {
  mutable contextTime?: float,
  mutable performanceTime?: float,
}

type uLongRange = {
  mutable max?: int,
  mutable min?: int,
}

type doubleRange = {
  mutable max?: float,
  mutable min?: float,
}

type mediaTrackCapabilities = {
  mutable width?: MediaCaptureAndStreamsTypes.uLongRange,
  mutable height?: MediaCaptureAndStreamsTypes.uLongRange,
  mutable aspectRatio?: MediaCaptureAndStreamsTypes.doubleRange,
  mutable frameRate?: MediaCaptureAndStreamsTypes.doubleRange,
  mutable facingMode?: array<string>,
  mutable sampleRate?: MediaCaptureAndStreamsTypes.uLongRange,
  mutable sampleSize?: MediaCaptureAndStreamsTypes.uLongRange,
  mutable echoCancellation?: array<bool>,
  mutable autoGainControl?: array<bool>,
  mutable noiseSuppression?: array<bool>,
  mutable channelCount?: MediaCaptureAndStreamsTypes.uLongRange,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: array<bool>,
  mutable displaySurface?: string,
}

type mediaTrackConstraintSet = {
  mutable width?: int,
  mutable height?: int,
  mutable aspectRatio?: float,
  mutable frameRate?: float,
  mutable facingMode?: string,
  mutable sampleRate?: int,
  mutable sampleSize?: int,
  mutable echoCancellation?: bool,
  mutable autoGainControl?: bool,
  mutable noiseSuppression?: bool,
  mutable channelCount?: int,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: bool,
  mutable displaySurface?: string,
}

type mediaTrackConstraints = {
  ...MediaCaptureAndStreamsTypes.mediaTrackConstraintSet,
  mutable advanced?: array<MediaCaptureAndStreamsTypes.mediaTrackConstraintSet>,
}

type mediaTrackSettings = {
  mutable width?: int,
  mutable height?: int,
  mutable aspectRatio?: float,
  mutable frameRate?: float,
  mutable facingMode?: string,
  mutable sampleRate?: int,
  mutable sampleSize?: int,
  mutable echoCancellation?: bool,
  mutable autoGainControl?: bool,
  mutable noiseSuppression?: bool,
  mutable channelCount?: int,
  mutable deviceId?: string,
  mutable groupId?: string,
  mutable backgroundBlur?: bool,
  mutable displaySurface?: string,
}

type audioBufferOptions = {
  mutable numberOfChannels?: int,
  mutable length: int,
  mutable sampleRate: float,
}

type audioProcessingEventInit = {
  ...EventTypes.eventInit,
  mutable playbackTime: float,
  mutable inputBuffer: audioBuffer,
  mutable outputBuffer: audioBuffer,
}

type offlineAudioCompletionEventInit = {
  ...EventTypes.eventInit,
  mutable renderedBuffer: audioBuffer,
}

type audioNodeOptions = {
  mutable channelCount?: int,
  mutable channelCountMode?: channelCountMode,
  mutable channelInterpretation?: channelInterpretation,
}

type biquadFilterOptions = {
  ...audioNodeOptions,
  @as("type") mutable type_?: biquadFilterType,
  @as("Q") mutable q?: float,
  mutable detune?: float,
  mutable frequency?: float,
  mutable gain?: float,
}

type audioBufferSourceOptions = {
  mutable buffer?: Null.t<audioBuffer>,
  mutable detune?: float,
  mutable loop?: bool,
  mutable loopEnd?: float,
  mutable loopStart?: float,
  mutable playbackRate?: float,
}

type channelMergerOptions = {
  ...audioNodeOptions,
  mutable numberOfInputs?: int,
}

type channelSplitterOptions = {
  ...audioNodeOptions,
  mutable numberOfOutputs?: int,
}

type constantSourceOptions = {mutable offset?: float}

type convolverOptions = {
  ...audioNodeOptions,
  mutable buffer?: Null.t<audioBuffer>,
  mutable disableNormalization?: bool,
}

type delayOptions = {
  ...audioNodeOptions,
  mutable maxDelayTime?: float,
  mutable delayTime?: float,
}

type dynamicsCompressorOptions = {
  ...audioNodeOptions,
  mutable attack?: float,
  mutable knee?: float,
  mutable ratio?: float,
  mutable release?: float,
  mutable threshold?: float,
}

type gainOptions = {
  ...audioNodeOptions,
  mutable gain?: float,
}

type iirFilterOptions = {
  ...audioNodeOptions,
  mutable feedforward: array<float>,
  mutable feedback: array<float>,
}

type oscillatorOptions = {
  ...audioNodeOptions,
  @as("type") mutable type_?: oscillatorType,
  mutable frequency?: float,
  mutable detune?: float,
  mutable periodicWave?: periodicWave,
}

type pannerOptions = {
  ...audioNodeOptions,
  mutable panningModel?: panningModelType,
  mutable distanceModel?: distanceModelType,
  mutable positionX?: float,
  mutable positionY?: float,
  mutable positionZ?: float,
  mutable orientationX?: float,
  mutable orientationY?: float,
  mutable orientationZ?: float,
  mutable refDistance?: float,
  mutable maxDistance?: float,
  mutable rolloffFactor?: float,
  mutable coneInnerAngle?: float,
  mutable coneOuterAngle?: float,
  mutable coneOuterGain?: float,
}

type analyserOptions = {
  ...audioNodeOptions,
  mutable fftSize?: int,
  mutable maxDecibels?: float,
  mutable minDecibels?: float,
  mutable smoothingTimeConstant?: float,
}

type periodicWaveOptions = {
  ...periodicWaveConstraints,
  mutable real?: array<float>,
  mutable imag?: array<float>,
}

type stereoPannerOptions = {
  ...audioNodeOptions,
  mutable pan?: float,
}

type waveShaperOptions = {
  ...audioNodeOptions,
  mutable curve?: array<float>,
  mutable oversample?: overSampleType,
}

type audioContextOptions = {
  mutable latencyHint?: unknown,
  mutable sampleRate?: float,
}

type mediaElementAudioSourceOptions = {mutable mediaElement: DomTypes.htmlMediaElement}

type mediaStreamAudioSourceOptions = {
  mutable mediaStream: MediaCaptureAndStreamsTypes.mediaStream,
}

type audioWorkletNodeOptions = {
  ...audioNodeOptions,
  mutable numberOfInputs?: int,
  mutable numberOfOutputs?: int,
  mutable outputChannelCount?: array<int>,
  mutable parameterData?: unknown,
  mutable processorOptions?: Dict.t<string>,
}

type offlineAudioContextOptions = {
  mutable numberOfChannels?: int,
  mutable length: int,
  mutable sampleRate: float,
}

type workletOptions = {mutable credentials?: requestCredentials}

type decodeSuccessCallback = audioBuffer => unit

type decodeErrorCallback = DOM.domException => unit
