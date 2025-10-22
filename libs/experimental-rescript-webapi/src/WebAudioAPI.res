@@warning("-30")

open Prelude
open ChannelMessagingAPI
open EventAPI
open DOMAPI
open MediaCaptureAndStreamsAPI

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

/**
A short audio asset residing in memory, created from an audio file using the AudioContext.decodeAudioData() method, or from raw data using AudioContext.createBuffer(). Once put into an AudioBuffer, the audio can then be played by being passed into an AudioBufferSourceNode.
[See AudioBuffer on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer)
*/
@editor.completeFrom(AudioBuffer)
type audioBuffer = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/sampleRate)
    */
  sampleRate: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/length)
    */
  length: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/duration)
    */
  duration: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBuffer/numberOfChannels)
    */
  numberOfChannels: int,
}

/**
The Web Audio API events that occur when a ScriptProcessorNode input buffer is ready to be processed.
[See AudioProcessingEvent on MDN](https://developer.mozilla.org/docs/Web/API/AudioProcessingEvent)
*/
@editor.completeFrom(AudioProcessingEvent)
type audioProcessingEvent = {
  ...event,
}

/**
The Web Audio API OfflineAudioCompletionEvent interface represents events that occur when the processing of an OfflineAudioContext is terminated. The complete event implements this interface.
[See OfflineAudioCompletionEvent on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioCompletionEvent)
*/
@editor.completeFrom(OfflineAudioCompletionEvent)
type offlineAudioCompletionEvent = {
  ...event,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioCompletionEvent/renderedBuffer)
    */
  renderedBuffer: audioBuffer,
}

/**
[See Worklet on MDN](https://developer.mozilla.org/docs/Web/API/Worklet)
*/
@editor.completeFrom(Worklet)
type worklet = {}

/**
A generic interface for representing an audio processing module. Examples include:
[See AudioNode on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode)
*/
@editor.completeFrom(AudioNode)
type rec audioNode = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
}

/**
AudioDestinationNode has no output (as it is the output, no more AudioNode can be linked after it in the audio graph) and one input. The number of channels in the input must be between 0 and the maxChannelCount value or an exception is raised.
[See AudioDestinationNode on MDN](https://developer.mozilla.org/docs/Web/API/AudioDestinationNode)
*/
and audioDestinationNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioDestinationNode/maxChannelCount)
    */
  maxChannelCount: int,
}

/**
[See BaseAudioContext on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext)
*/
@editor.completeFrom(BaseAudioContext) and baseAudioContext = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/destination)
    */
  destination: audioDestinationNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/sampleRate)
    */
  sampleRate: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/currentTime)
    */
  currentTime: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/listener)
    */
  listener: audioListener,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/state)
    */
  state: audioContextState,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BaseAudioContext/audioWorklet)
    */
  audioWorklet: audioWorklet,
}

/**
A simple low-order filter, and is created using the AudioContext.createBiquadFilter() method. It is an AudioNode that can represent different kinds of filters, tone control devices, and graphic equalizers.
[See BiquadFilterNode on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode)
*/
@editor.completeFrom(BiquadFilterNode) and biquadFilterNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/type)
    */
  @as("type")
  mutable type_: biquadFilterType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/frequency)
    */
  frequency: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/detune)
    */
  detune: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/Q)
    */
  @as("Q")
  q: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/gain)
    */
  gain: audioParam,
}

/**
The position and orientation of the unique person listening to the audio scene, and is used in audio spatialization. All PannerNodes spatialize in relation to the AudioListener stored in the BaseAudioContext.listener attribute.
[See AudioListener on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener)
*/
and audioListener = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/positionX)
    */
  positionX: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/positionY)
    */
  positionY: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/positionZ)
    */
  positionZ: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/forwardX)
    */
  forwardX: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/forwardY)
    */
  forwardY: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/forwardZ)
    */
  forwardZ: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/upX)
    */
  upX: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/upY)
    */
  upY: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioListener/upZ)
    */
  upZ: audioParam,
}

/**
[See AudioWorklet on MDN](https://developer.mozilla.org/docs/Web/API/AudioWorklet)
*/
and audioWorklet = {
  ...worklet,
}

/**
The Web Audio API's AudioParam interface represents an audio-related parameter, usually a parameter of an AudioNode (such as GainNode.gain).
[See AudioParam on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam)
*/
@editor.completeFrom(AudioParam) and audioParam = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/value)
    */
  mutable value: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/defaultValue)
    */
  defaultValue: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/minValue)
    */
  minValue: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioParam/maxValue)
    */
  maxValue: float,
}

/**
[See AudioScheduledSourceNode on MDN](https://developer.mozilla.org/docs/Web/API/AudioScheduledSourceNode)
*/
@editor.completeFrom(AudioScheduledSourceNode) and audioScheduledSourceNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode
}

/**
An AudioScheduledSourceNode which represents an audio source consisting of in-memory audio data, stored in an AudioBuffer. It's especially useful for playing back audio which has particularly stringent timing accuracy requirements, such as for sounds that must match a specific rhythm and can be kept in memory rather than being played from disk or the network.
[See AudioBufferSourceNode on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode)
*/
@editor.completeFrom(AudioBufferSourceNode) and audioBufferSourceNode = {
  // Base properties from AudioScheduledSourceNode
  // End base properties from AudioScheduledSourceNode

  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/buffer)
    */
  mutable buffer: Null.t<audioBuffer>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/playbackRate)
    */
  playbackRate: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/detune)
    */
  detune: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/loop)
    */
  mutable loop: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/loopStart)
    */
  mutable loopStart: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/loopEnd)
    */
  mutable loopEnd: float,
}

/**
The ChannelMergerNode interface, often used in conjunction with its opposite, ChannelSplitterNode, reunites different mono inputs into a single output. Each input is used to fill a channel of the output. This is useful for accessing each channels separately, e.g. for performing channel mixing where gain must be separately controlled on each channel.
[See ChannelMergerNode on MDN](https://developer.mozilla.org/docs/Web/API/ChannelMergerNode)
*/
@editor.completeFrom(ChannelMergerNode) and channelMergerNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode
}

/**
The ChannelSplitterNode interface, often used in conjunction with its opposite, ChannelMergerNode, separates the different channels of an audio source into a set of mono outputs. This is useful for accessing each channel separately, e.g. for performing channel mixing where gain must be separately controlled on each channel.
[See ChannelSplitterNode on MDN](https://developer.mozilla.org/docs/Web/API/ChannelSplitterNode)
*/
@editor.completeFrom(ChannelSplitterNode) and channelSplitterNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode
}

/**
[See ConstantSourceNode on MDN](https://developer.mozilla.org/docs/Web/API/ConstantSourceNode)
*/
@editor.completeFrom(ConstantSourceNode) and constantSourceNode = {
  // Base properties from AudioScheduledSourceNode
  // End base properties from AudioScheduledSourceNode

  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConstantSourceNode/offset)
    */
  offset: audioParam,
}

/**
An AudioNode that performs a Linear Convolution on a given AudioBuffer, often used to achieve a reverb effect. A ConvolverNode always has exactly one input and one output.
[See ConvolverNode on MDN](https://developer.mozilla.org/docs/Web/API/ConvolverNode)
*/
@editor.completeFrom(ConvolverNode) and convolverNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConvolverNode/buffer)
    */
  mutable buffer: Null.t<audioBuffer>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConvolverNode/normalize)
    */
  mutable normalize: bool,
}

/**
A delay-line; an AudioNode audio-processing module that causes a delay between the arrival of an input data and its propagation to the output.
[See DelayNode on MDN](https://developer.mozilla.org/docs/Web/API/DelayNode)
*/
@editor.completeFrom(DelayNode) and delayNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DelayNode/delayTime)
    */
  delayTime: audioParam,
}

/**
Inherits properties from its parent, AudioNode.
[See DynamicsCompressorNode on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode)
*/
@editor.completeFrom(DynamicsCompressorNode) and dynamicsCompressorNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/threshold)
    */
  threshold: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/knee)
    */
  knee: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/ratio)
    */
  ratio: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/reduction)
    */
  reduction: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/attack)
    */
  attack: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode/release)
    */
  release: audioParam,
}

/**
A change in volume. It is an AudioNode audio-processing module that causes a given gain to be applied to the input data before its propagation to the output. A GainNode always has exactly one input and one output, both with the same number of channels.
[See GainNode on MDN](https://developer.mozilla.org/docs/Web/API/GainNode)
*/
@editor.completeFrom(GainNode) and gainNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/GainNode/gain)
    */
  gain: audioParam,
}

/**
The IIRFilterNode interface of the Web Audio API is a AudioNode processor which implements a general infinite impulse response (IIR)  filter; this type of filter can be used to implement tone control devices and graphic equalizers as well. It lets the parameters of the filter response be specified, so that it can be tuned as needed.
[See IIRFilterNode on MDN](https://developer.mozilla.org/docs/Web/API/IIRFilterNode)
*/
@editor.completeFrom(IIRFilterNode) and iirFilterNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode
}

/**
The OscillatorNode interface represents a periodic waveform, such as a sine wave. It is an AudioScheduledSourceNode audio-processing module that causes a specified frequency of a given wave to be created—in effect, a constant tone.
[See OscillatorNode on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode)
*/
@editor.completeFrom(OscillatorNode) and oscillatorNode = {
  // Base properties from AudioScheduledSourceNode
  // End base properties from AudioScheduledSourceNode

  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode/type)
    */
  @as("type")
  mutable type_: oscillatorType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode/frequency)
    */
  frequency: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode/detune)
    */
  detune: audioParam,
}

/**
A PannerNode always has exactly one input and one output: the input can be mono or stereo but the output is always stereo (2 channels); you can't have panning effects without at least two audio channels!
[See PannerNode on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode)
*/
@editor.completeFrom(PannerNode) and pannerNode = {
  // Base properties from AudioNode
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/context)
    */
  context: baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfInputs)
    */
  numberOfInputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/numberOfOutputs)
    */
  numberOfOutputs: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCount)
    */
  mutable channelCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelCountMode)
    */
  mutable channelCountMode: channelCountMode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioNode/channelInterpretation)
    */
  mutable channelInterpretation: channelInterpretation,
  // End base properties from AudioNode

  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/panningModel)
    */
  mutable panningModel: panningModelType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/positionX)
    */
  positionX: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/positionY)
    */
  positionY: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/positionZ)
    */
  positionZ: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/orientationX)
    */
  orientationX: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/orientationY)
    */
  orientationY: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/orientationZ)
    */
  orientationZ: audioParam,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/distanceModel)
    */
  mutable distanceModel: distanceModelType,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/refDistance)
    */
  mutable refDistance: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/maxDistance)
    */
  mutable maxDistance: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/rolloffFactor)
    */
  mutable rolloffFactor: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/coneInnerAngle)
    */
  mutable coneInnerAngle: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/coneOuterAngle)
    */
  mutable coneOuterAngle: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode/coneOuterGain)
    */
  mutable coneOuterGain: float,
}

/**
A node able to provide real-time frequency and time-domain analysis information. It is an AudioNode that passes the audio stream unchanged from the input to the output, but allows you to take the generated data, process it, and create audio visualizations.
[See AnalyserNode on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode)
*/
@editor.completeFrom(AnalyserNode)
type analyserNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/fftSize)
    */
  mutable fftSize: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/frequencyBinCount)
    */
  frequencyBinCount: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/minDecibels)
    */
  mutable minDecibels: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/maxDecibels)
    */
  mutable maxDecibels: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/smoothingTimeConstant)
    */
  mutable smoothingTimeConstant: float,
}

/**
PeriodicWave has no inputs or outputs; it is used to define custom oscillators when calling OscillatorNode.setPeriodicWave(). The PeriodicWave itself is created/returned by AudioContext.createPeriodicWave().
[See PeriodicWave on MDN](https://developer.mozilla.org/docs/Web/API/PeriodicWave)
*/
@editor.completeFrom(PeriodicWave)
type periodicWave = {}

/**
The pan property takes a unitless value between -1 (full left pan) and 1 (full right pan). This interface was introduced as a much simpler way to apply a simple panning effect than having to use a full PannerNode.
[See StereoPannerNode on MDN](https://developer.mozilla.org/docs/Web/API/StereoPannerNode)
*/
@editor.completeFrom(StereoPannerNode)
type stereoPannerNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/StereoPannerNode/pan)
    */
  pan: audioParam,
}

/**
A WaveShaperNode always has exactly one input and one output.
[See WaveShaperNode on MDN](https://developer.mozilla.org/docs/Web/API/WaveShaperNode)
*/
@editor.completeFrom(WaveShaperNode)
type waveShaperNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WaveShaperNode/curve)
    */
  mutable curve: Null.t<array<float>>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WaveShaperNode/oversample)
    */
  mutable oversample: overSampleType,
}

/**
An audio-processing graph built from audio modules linked together, each represented by an AudioNode.
[See AudioContext on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext)
*/
@editor.completeFrom(AudioContext)
type audioContext = {
  ...baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/baseLatency)
    */
  baseLatency: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioContext/outputLatency)
    */
  outputLatency: float,
}

/**
A MediaElementSourceNode has no inputs and exactly one output, and is created using the AudioContext.createMediaElementSource method. The amount of channels in the output equals the number of channels of the audio referenced by the HTMLMediaElement used in the creation of the node, or is 1 if the HTMLMediaElement has no audio.
[See MediaElementAudioSourceNode on MDN](https://developer.mozilla.org/docs/Web/API/MediaElementAudioSourceNode)
*/
@editor.completeFrom(MediaElementAudioSourceNode)
type mediaElementAudioSourceNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaElementAudioSourceNode/mediaElement)
    */
  mediaElement: htmlMediaElement,
}

/**
A type of AudioNode which operates as an audio source whose media is received from a MediaStream obtained using the WebRTC or Media Capture and Streams APIs.
[See MediaStreamAudioSourceNode on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioSourceNode)
*/
@editor.completeFrom(MediaStreamAudioSourceNode)
type mediaStreamAudioSourceNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioSourceNode/mediaStream)
    */
  mediaStream: mediaStream,
}

/**
[See MediaStreamAudioDestinationNode on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioDestinationNode)
*/
@editor.completeFrom(MediaStreamAudioDestinationNode)
type mediaStreamAudioDestinationNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioDestinationNode/stream)
    */
  stream: mediaStream,
}

/**
[See AudioParamMap on MDN](https://developer.mozilla.org/docs/Web/API/AudioParamMap)
*/
type audioParamMap = {}

/**
[See AudioWorkletNode on MDN](https://developer.mozilla.org/docs/Web/API/AudioWorkletNode)
*/
@editor.completeFrom(AudioWorkletNode)
type audioWorkletNode = {
  ...audioNode,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioWorkletNode/parameters)
    */
  parameters: audioParamMap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioWorkletNode/port)
    */
  port: messagePort,
}

/**
An AudioContext interface representing an audio-processing graph built from linked together AudioNodes. In contrast with a standard AudioContext, an OfflineAudioContext doesn't render the audio to the device hardware; instead, it generates it, as fast as it can, and outputs the result to an AudioBuffer.
[See OfflineAudioContext on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext)
*/
@editor.completeFrom(OfflineAudioContext)
type offlineAudioContext = {
  ...baseAudioContext,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioContext/length)
    */
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
  mutable width?: uLongRange,
  mutable height?: uLongRange,
  mutable aspectRatio?: doubleRange,
  mutable frameRate?: doubleRange,
  mutable facingMode?: array<string>,
  mutable sampleRate?: uLongRange,
  mutable sampleSize?: uLongRange,
  mutable echoCancellation?: array<bool>,
  mutable autoGainControl?: array<bool>,
  mutable noiseSuppression?: array<bool>,
  mutable channelCount?: uLongRange,
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
  ...mediaTrackConstraintSet,
  mutable advanced?: array<mediaTrackConstraintSet>,
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
  ...eventInit,
  mutable playbackTime: float,
  mutable inputBuffer: audioBuffer,
  mutable outputBuffer: audioBuffer,
}

type offlineAudioCompletionEventInit = {
  ...eventInit,
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

type mediaElementAudioSourceOptions = {mutable mediaElement: htmlMediaElement}

type mediaStreamAudioSourceOptions = {mutable mediaStream: mediaStream}

type audioWorkletNodeOptions = {
  ...audioNodeOptions,
  mutable numberOfInputs?: int,
  mutable numberOfOutputs?: int,
  mutable outputChannelCount?: array<int>,
  mutable parameterData?: any,
  mutable processorOptions?: Dict.t<string>,
}

type offlineAudioContextOptions = {
  mutable numberOfChannels?: int,
  mutable length: int,
  mutable sampleRate: float,
}

type workletOptions = {mutable credentials?: requestCredentials}

type decodeSuccessCallback = audioBuffer => unit

type decodeErrorCallback = domException => unit
